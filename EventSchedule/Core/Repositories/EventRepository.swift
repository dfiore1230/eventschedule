import Foundation

@inline(__always)
private func consoleLog(_ message: String) {
    DebugLogger.log(message)
    print(message)
}

@inline(__always)
private func consoleError(_ message: String) {
    DebugLogger.error(message)
    fputs(message + "\n", stderr)
}

@inline(__always)
private func apiDateString(_ date: Date, timeZone: TimeZone) -> String {
    struct FormatterCache {
        static var cache: [String: DateFormatter] = [:]
    }

    if let cached = FormatterCache.cache[timeZone.identifier] {
        return cached.string(from: date)
    }

    let formatter = Event.payloadDateFormatter(timeZone: timeZone)
    FormatterCache.cache[timeZone.identifier] = formatter
    return formatter.string(from: date)
}

protocol EventRepository {
    func listEvents(for instance: InstanceProfile) async throws -> [Event]
    func getEvent(id: String, instance: InstanceProfile) async throws -> Event
    func listVenues(for instance: InstanceProfile) async throws -> [Venue]
    func listEventResources(for instance: InstanceProfile) async throws -> EventResources
    func createEvent(_ event: Event, instance: InstanceProfile, timeZoneOverride: TimeZone?) async throws -> Event
    func updateEvent(_ event: Event, instance: InstanceProfile, timeZoneOverride: TimeZone?) async throws -> Event
    func deleteEvent(id: String, instance: InstanceProfile) async throws
    func patchEvent<T: Encodable>(id: String, body: T, instance: InstanceProfile) async throws -> Event
}

extension EventRepository {
    func createEvent(_ event: Event, instance: InstanceProfile) async throws -> Event {
        try await createEvent(event, instance: instance, timeZoneOverride: nil)
    }

    func updateEvent(_ event: Event, instance: InstanceProfile) async throws -> Event {
        try await updateEvent(event, instance: instance, timeZoneOverride: nil)
    }
}

private struct EventListResponse: Decodable {
    let events: [Event]

    init(from decoder: Decoder) throws {
        if let directArray = try? decoder.singleValueContainer().decode([Event].self) {
            events = directArray
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)

        if let dataArray = try container.decodeIfPresent([Event].self, forKey: .data) {
            events = dataArray
            return
        }

        if let eventsArray = try container.decodeIfPresent([Event].self, forKey: .events) {
            events = eventsArray
            return
        }

        if let itemsArray = try container.decodeIfPresent([Event].self, forKey: .items) {
            events = itemsArray
            return
        }

        if let nestedData = try? container.nestedContainer(keyedBy: NestedCodingKeys.self, forKey: .data) {
            if let nestedEvents = try nestedData.decodeIfPresent([Event].self, forKey: .events) {
                events = nestedEvents
                return
            }

            if let nestedItems = try nestedData.decodeIfPresent([Event].self, forKey: .items) {
                events = nestedItems
                return
            }

            if let deeperData = try? nestedData.nestedContainer(keyedBy: NestedCodingKeys.self, forKey: .data) {
                if let deepItems = try deeperData.decodeIfPresent([Event].self, forKey: .items) {
                    events = deepItems
                    return
                }
            }
        }

        // Final fallback: explicit envelope { data: [Event], meta: {...} }
        struct Envelope: Decodable {
            let data: [Event]
            let meta: Meta?
        }
        struct Meta: Decodable {
            let current_page: Int?
            let from: Int?
            let last_page: Int?
            let per_page: Int?
            let to: Int?
            let total: Int?
            let path: String?
        }
        if let envelope = try? Envelope(from: decoder) {
            events = envelope.data
            return
        }

        consoleError("EventListResponse: Unable to locate events array. CodingPath=\(decoder.codingPath.map { $0.stringValue }.joined(separator: ".")) attempted keys: data, events, items; nested data.events, data.items, data.data.items")
        throw DecodingError.dataCorruptedError(
            forKey: .data,
            in: container,
            debugDescription: "No events array found in response"
        )
    }

    private enum CodingKeys: String, CodingKey {
        case data
        case events
        case items
    }

    private enum NestedCodingKeys: String, CodingKey {
        case data
        case events
        case items
    }
}

private struct EventDetailResponse: Decodable {
    let event: Event

    init(from decoder: Decoder) throws {
        if let directEvent = try? decoder.singleValueContainer().decode(Event.self) {
            event = directEvent
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)

        if let dataEvent = try container.decodeIfPresent(Event.self, forKey: .data) {
            event = dataEvent
            return
        }

        if let wrappedEvent = try container.decodeIfPresent(Event.self, forKey: .event) {
            event = wrappedEvent
            return
        }

        if let nestedData = try? container.nestedContainer(keyedBy: NestedCodingKeys.self, forKey: .data) {
            if let nestedEvent = try nestedData.decodeIfPresent(Event.self, forKey: .event) {
                event = nestedEvent
                return
            }

            if let deeperEvent = try nestedData.decodeIfPresent(Event.self, forKey: .data) {
                event = deeperEvent
                return
            }
        }

        // Final fallback: explicit envelope { data: Event }
        struct Envelope: Decodable { let data: Event }
        if let envelope = try? Envelope(from: decoder) {
            event = envelope.data
            return
        }

        consoleError("EventDetailResponse: Unable to locate event object. CodingPath=\(decoder.codingPath.map { $0.stringValue }.joined(separator: ".")) attempted keys: data, event; nested data.event, data.data")
        throw DecodingError.dataCorruptedError(
            forKey: .data,
            in: container,
            debugDescription: "No event object found in response"
        )
    }

    private enum CodingKeys: String, CodingKey {
        case data
        case event
    }

    private enum NestedCodingKeys: String, CodingKey {
        case data
        case event
    }
}

final class RemoteEventRepository: EventRepository {
    private let httpClient: HTTPClientProtocol
    private let payloadTimeZoneProvider: () -> TimeZone
    private var cache: [UUID: [Event]] = [:]
    private var venueCache: [UUID: [Venue]] = [:]
    private var resourcesCache: [UUID: EventResources] = [:]
    private var subdomainCache: [UUID: (subdomain: String, type: String?)] = [:]

    init(httpClient: HTTPClientProtocol = HTTPClient(), payloadTimeZoneProvider: @escaping () -> TimeZone = { .current }) {
        self.httpClient = httpClient
        self.payloadTimeZoneProvider = payloadTimeZoneProvider
    }

    private func enrichVenueNames(_ events: [Event], for instance: InstanceProfile) async -> [Event] {
        var venues = venueCache[instance.id] ?? []
        if venues.isEmpty {
            if let res = try? await listEventResources(for: instance) {
                venues = res.venues.map { Venue(id: $0.id, name: $0.name) }
            }
        }
        let map = Dictionary(uniqueKeysWithValues: venues.map { ($0.id, $0.name) })
        return events.map { e in
            if e.venueName == nil, let name = map[e.venueId] {
                var copy = e
                copy.venueName = name
                DebugLogger.log("Enrichment: set venue name for event id=\(e.id) -> \(name)")
                return copy
            }
            return e
        }
    }

    private func enrichVenueName(_ event: Event, for instance: InstanceProfile) async -> Event {
        if event.venueName != nil { return event }
        var venues = venueCache[instance.id] ?? []
        if venues.isEmpty {
            if let res = try? await listEventResources(for: instance) {
                venues = res.venues.map { Venue(id: $0.id, name: $0.name) }
            }
        }
        if let name = venues.first(where: { $0.id == event.venueId })?.name {
            var copy = event
            copy.venueName = name
            DebugLogger.log("Enrichment: set venue name for event id=\(event.id) -> \(name)")
            return copy
        }
        return event
    }

    func listEvents(for instance: InstanceProfile) async throws -> [Event] {
        do {
            let response: EventListResponse = try await httpClient.request(
                "events",
                method: .get,
                query: ["include": "venue,talent,tickets"],
                body: Optional<Event>.none,
                instance: instance
            )
            let enriched = await enrichVenueNames(response.events, for: instance)
            cache[instance.id] = enriched
            consoleLog("RemoteEventRepository: fetched \(enriched.count) events for instance=\(instance.displayName) (id=\(instance.id))")
            return enriched
        } catch {
            consoleError("RemoteEventRepository: listEvents failed for instance=\(instance.displayName) (id=\(instance.id)) error=\(error.localizedDescription)")
            if case let DecodingError.dataCorrupted(context) = error {
                consoleError("DecodingError.dataCorrupted: codingPath=\(context.codingPath.map { $0.stringValue }.joined(separator: ".")) debug=\(context.debugDescription)")
            } else if case let DecodingError.keyNotFound(key, context) = error {
                consoleError("DecodingError.keyNotFound: key=\(key.stringValue) codingPath=\(context.codingPath.map { $0.stringValue }.joined(separator: ".")) debug=\(context.debugDescription)")
            } else if case let DecodingError.typeMismatch(type, context) = error {
                consoleError("DecodingError.typeMismatch: type=\(type) codingPath=\(context.codingPath.map { $0.stringValue }.joined(separator: ".")) debug=\(context.debugDescription)")
            } else if case let DecodingError.valueNotFound(type, context) = error {
                consoleError("DecodingError.valueNotFound: type=\(type) codingPath=\(context.codingPath.map { $0.stringValue }.joined(separator: ".")) debug=\(context.debugDescription)")
            }
            if let cached = cache[instance.id] {
                consoleLog("RemoteEventRepository: returning \(cached.count) cached events after list failure for instance=\(instance.displayName) (id=\(instance.id))")
                return cached
            }
            throw error
        }
    }

    func getEvent(id: String, instance: InstanceProfile) async throws -> Event {
        do {
            let response: EventDetailResponse = try await httpClient.request(
                "events/\(id)",
                method: .get,
                query: ["include": "venue,talent,tickets"],
                body: Optional<Event>.none,
                instance: instance
            )
            let enriched = await enrichVenueName(response.event, for: instance)
            upsert(enriched, for: instance)
            consoleLog("RemoteEventRepository: fetched event id=\(enriched.id) for instance=\(instance.displayName) (id=\(instance.id))")
            return enriched
        } catch {
            consoleError("RemoteEventRepository: getEvent failed for id=\(id) on instance=\(instance.displayName) (id=\(instance.id)) error=\(error.localizedDescription)")
            if case let DecodingError.dataCorrupted(context) = error {
                consoleError("DecodingError.dataCorrupted: codingPath=\(context.codingPath.map { $0.stringValue }.joined(separator: ".")) debug=\(context.debugDescription)")
            } else if case let DecodingError.keyNotFound(key, context) = error {
                consoleError("DecodingError.keyNotFound: key=\(key.stringValue) codingPath=\(context.codingPath.map { $0.stringValue }.joined(separator: ".")) debug=\(context.debugDescription)")
            } else if case let DecodingError.typeMismatch(type, context) = error {
                consoleError("DecodingError.typeMismatch: type=\(type) codingPath=\(context.codingPath.map { $0.stringValue }.joined(separator: ".")) debug=\(context.debugDescription)")
            } else if case let DecodingError.valueNotFound(type, context) = error {
                consoleError("DecodingError.valueNotFound: type=\(type) codingPath=\(context.codingPath.map { $0.stringValue }.joined(separator: ".")) debug=\(context.debugDescription)")
            }
            if let cachedEvent = cache[instance.id]?.first(where: { $0.id == id }) {
                consoleLog("RemoteEventRepository: returning cached event id=\(id) after fetch failure on instance=\(instance.displayName) (id=\(instance.id))")
                return cachedEvent
            }
            throw error
        }
    }

    func listVenues(for instance: InstanceProfile) async throws -> [Venue] {
        let resources = try await listEventResources(for: instance)
        return resources.venues.map { Venue(id: $0.id, name: $0.name) }
    }

    func listEventResources(for instance: InstanceProfile) async throws -> EventResources {
        struct ResourcesResponse: Decodable {
            let resources: EventResources

            init(from decoder: Decoder) throws {
                if let direct = try? EventResources(from: decoder) {
                    resources = direct
                    return
                }

                let container = try decoder.container(keyedBy: CodingKeys.self)
                if let nested = try container.decodeIfPresent(EventResources.self, forKey: .data) {
                    resources = nested
                    return
                }

                if let venues = try container.decodeIfPresent([EventRole].self, forKey: .venues) {
                    let curators = try container.decodeIfPresent([EventRole].self, forKey: .curators) ?? []
                    let talent = try container.decodeIfPresent([EventRole].self, forKey: .talent) ?? []
                    let categories = try container.decodeIfPresent([String].self, forKey: .categories) ?? []
                    let groups = try container.decodeIfPresent([EventGroup].self, forKey: .groups) ?? []
                    resources = EventResources(venues: venues, curators: curators, talent: talent, categories: categories, groups: groups)
                    return
                }

                consoleError("ResourcesResponse: Unable to decode resources. CodingPath=\(decoder.codingPath.map { $0.stringValue }.joined(separator: "."))")
                throw DecodingError.dataCorruptedError(forKey: .data, in: container, debugDescription: "No resources found in response")
            }

            private enum CodingKeys: String, CodingKey {
                case data
                case venues
                case curators
                case talent
                case categories
                case groups
            }
        }

        do {
            let response: ResourcesResponse = try await httpClient.request(
                "events/resources",
                method: .get,
                query: ["per_page": "1000"],
                body: (nil as (any Encodable)?),
                instance: instance
            )
            resourcesCache[instance.id] = response.resources
            venueCache[instance.id] = response.resources.venues.map { Venue(id: $0.id, name: $0.name) }
            consoleLog("RemoteEventRepository: fetched event resources venues=\(response.resources.venues.count) curators=\(response.resources.curators.count) talent=\(response.resources.talent.count) for instance=\(instance.displayName) (id=\(instance.id))")
            return response.resources
        } catch {
            consoleError("RemoteEventRepository: listEventResources failed for instance=\(instance.displayName) (id=\(instance.id)) error=\(error.localizedDescription)")
            if let cached = resourcesCache[instance.id] {
                consoleLog("RemoteEventRepository: returning cached resources after failure for instance=\(instance.displayName) (id=\(instance.id))")
                return cached
            }
            throw error
        }
    }

    func createEvent(
        _ event: Event,
        instance: InstanceProfile,
        timeZoneOverride: TimeZone? = nil
    ) async throws -> Event {
        let (subdomain, scheduleType) = try await resolveSubdomain(for: instance)
        let includeVenueId = !(scheduleType?.lowercased().contains("venue") ?? false)
        DebugLogger.log("RemoteEventRepository: creating under subdomain=\(subdomain) type=\(scheduleType ?? "<nil>") includeVenueId=\(includeVenueId)")
        let payloadTimeZone = timeZoneOverride ?? payloadTimeZoneProvider()
        EventInstrumentation.log(
            action: "event_create_request",
            eventId: event.id,
            eventName: event.name,
            instance: instance,
            metadata: [
                "includeVenueId": String(includeVenueId),
                "payloadTimeZone": payloadTimeZone.identifier,
                "hasOnlineUrl": String(event.onlineURL != nil)
            ]
        )
        let dto = CreateEventDTO(
            id: event.id,
            name: event.name,
            description: event.description,
            startsAt: apiDateString(event.startAt, timeZone: payloadTimeZone),
            endAt: apiDateString(event.endAt, timeZone: payloadTimeZone),
            durationMinutes: event.durationMinutes,
            venueId: includeVenueId ? (event.venueId.isEmpty ? nil : event.venueId) : nil,
            roomId: event.roomId,
            status: event.status,
            images: event.images,
            capacity: event.capacity,
            ticketTypes: event.ticketTypes,
            publishState: event.publishState,
            curatorId: event.curatorId,
            members: event.talentIds.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty },
            category: event.category,
            groupSlug: event.groupSlug,
            url: event.onlineURL
        )
        do {
            let response: EventDetailResponse = try await httpClient.request(
                "events/\(subdomain)",
                method: .post,
                query: ["include": "venue,talent,tickets"],
                body: dto,
                instance: instance
            )
            let enriched = await enrichVenueName(response.event, for: instance)
            upsert(enriched, for: instance)
            consoleLog("RemoteEventRepository: created event id=\(enriched.id) for instance=\(instance.displayName) (id=\(instance.id))")
            EventInstrumentation.log(
                action: "event_create_success",
                eventId: enriched.id,
                eventName: enriched.name,
                instance: instance,
                metadata: [
                    "venueId": enriched.venueId,
                    "status": enriched.status.rawValue
                ]
            )
            return enriched
        } catch {
            consoleError("RemoteEventRepository: createEvent failed on instance=\(instance.displayName) (id=\(instance.id)) error=\(error.localizedDescription)")
            EventInstrumentation.error(
                action: "event_create_failure",
                eventId: event.id,
                eventName: event.name,
                instance: instance,
                error: error,
                metadata: [
                    "payloadTimeZone": (timeZoneOverride ?? payloadTimeZoneProvider()).identifier
                ]
            )
            if case let DecodingError.dataCorrupted(context) = error {
                consoleError("DecodingError.dataCorrupted: codingPath=\(context.codingPath.map { $0.stringValue }.joined(separator: ".")) debug=\(context.debugDescription)")
            } else if case let DecodingError.keyNotFound(key, context) = error {
                consoleError("DecodingError.keyNotFound: key=\(key.stringValue) codingPath=\(context.codingPath.map { $0.stringValue }.joined(separator: ".")) debug=\(context.debugDescription)")
            } else if case let DecodingError.typeMismatch(type, context) = error {
                consoleError("DecodingError.typeMismatch: type=\(type) codingPath=\(context.codingPath.map { $0.stringValue }.joined(separator: ".")) debug=\(context.debugDescription)")
            } else if case let DecodingError.valueNotFound(type, context) = error {
                consoleError("DecodingError.valueNotFound: type=\(type) codingPath=\(context.codingPath.map { $0.stringValue }.joined(separator: ".")) debug=\(context.debugDescription)")
            }
            throw error
        }
    }

    func updateEvent(
        _ event: Event,
        instance: InstanceProfile,
        timeZoneOverride: TimeZone? = nil
    ) async throws -> Event {
        do {
            let (_, scheduleType) = try await resolveSubdomain(for: instance)
            let resources: EventResources
            if let cachedResources = resourcesCache[instance.id] {
                resources = cachedResources
            } else {
                resources = try await listEventResources(for: instance)
            }
            let validVenueIds = Set(resources.venues.map { $0.id })
            let validTalentIds = Set(resources.talent.map { $0.id })
            let includeVenueId = !(scheduleType?.lowercased().contains("venue") ?? false)
            let safeVenueId: String?
            if !includeVenueId {
                safeVenueId = nil
            } else if event.venueId.isEmpty {
                safeVenueId = nil
            } else if validVenueIds.contains(event.venueId) {
                safeVenueId = event.venueId
            } else {
                safeVenueId = nil
            }
            let safeMembers: [String] = event.talentIds.filter { id in
                let trimmed = id.trimmingCharacters(in: .whitespacesAndNewlines)
                return !trimmed.isEmpty && validTalentIds.contains(trimmed)
            }
            let payloadTimeZone = timeZoneOverride ?? payloadTimeZoneProvider()
            let dto = UpdateEventDTO(
                id: event.id,
                name: event.name,
                description: event.description,
                startsAt: apiDateString(event.startAt, timeZone: payloadTimeZone),
                endAt: apiDateString(event.endAt, timeZone: payloadTimeZone),
                durationMinutes: event.durationMinutes,
                venueId: safeVenueId,
                roomId: event.roomId,
                status: event.status,
                images: event.images,
                capacity: event.capacity,
                ticketTypes: event.ticketTypes,
                publishState: event.publishState,
                curatorId: event.curatorId,
                members: safeMembers,
                category: event.category,
                groupSlug: event.groupSlug,
                url: event.onlineURL
            )
            EventInstrumentation.log(
                action: "event_update_request",
                eventId: event.id,
                eventName: event.name,
                instance: instance,
                metadata: [
                    "payloadTimeZone": payloadTimeZone.identifier,
                    "includeVenueId": String(includeVenueId),
                    "membersCount": String(safeMembers.count)
                ]
            )
            let response: EventDetailResponse = try await httpClient.request(
                "events/\(event.id)",
                method: .post,
                query: ["include": "venue,talent,tickets"],
                body: dto,
                instance: instance
            )
            let enriched = await enrichVenueName(response.event, for: instance)
            upsert(enriched, for: instance)
            consoleLog("RemoteEventRepository: updated event id=\(enriched.id) for instance=\(instance.displayName) (id=\(instance.id))")
            EventInstrumentation.log(
                action: "event_update_success",
                eventId: enriched.id,
                eventName: enriched.name,
                instance: instance,
                metadata: [
                    "status": enriched.status.rawValue,
                    "publishState": enriched.publishState.rawValue
                ]
            )
            return enriched
        } catch {
            consoleError("RemoteEventRepository: updateEvent failed for id=\(event.id) on instance=\(instance.displayName) (id=\(instance.id)) error=\(error.localizedDescription)")
            EventInstrumentation.error(
                action: "event_update_failure",
                eventId: event.id,
                eventName: event.name,
                instance: instance,
                error: error
            )
            if case let DecodingError.dataCorrupted(context) = error {
                consoleError("DecodingError.dataCorrupted: codingPath=\(context.codingPath.map { $0.stringValue }.joined(separator: ".")) debug=\(context.debugDescription)")
            } else if case let DecodingError.keyNotFound(key, context) = error {
                consoleError("DecodingError.keyNotFound: key=\(key.stringValue) codingPath=\(context.codingPath.map { $0.stringValue }.joined(separator: ".")) debug=\(context.debugDescription)")
            } else if case let DecodingError.typeMismatch(type, context) = error {
                consoleError("DecodingError.typeMismatch: type=\(type) codingPath=\(context.codingPath.map { $0.stringValue }.joined(separator: ".")) debug=\(context.debugDescription)")
            } else if case let DecodingError.valueNotFound(type, context) = error {
                consoleError("DecodingError.valueNotFound: type=\(type) codingPath=\(context.codingPath.map { $0.stringValue }.joined(separator: ".")) debug=\(context.debugDescription)")
            }
            throw error
        }
    }

    func deleteEvent(id: String, instance: InstanceProfile) async throws {
        do {
            try await httpClient.requestVoid(
                "events/\(id)",
                method: .delete,
                query: nil,
                body: Optional<Event>.none,
                instance: instance
            )
            removeFromCache(id: id, instance: instance)
            consoleLog("RemoteEventRepository: deleted event id=\(id) for instance=\(instance.displayName) (id=\(instance.id))")
        } catch {
            consoleError("RemoteEventRepository: deleteEvent failed for id=\(id) on instance=\(instance.displayName) (id=\(instance.id)) error=\(error.localizedDescription)")
            throw error
        }
    }

    func patchEvent<T: Encodable>(id: String, body: T, instance: InstanceProfile) async throws -> Event {
        do {
            EventInstrumentation.log(
                action: "event_patch_request",
                eventId: id,
                instance: instance,
                metadata: ["bodyType": String(describing: T.self)]
            )
            let response: GenericEventResponse = try await httpClient.request(
                "events/\(id)",
                method: .patch,
                query: ["include": "venue,talent,tickets"],
                body: body,
                instance: instance
            )
            upsert(response.data, for: instance)
            consoleLog("RemoteEventRepository: patched event id=\(response.data.id) for instance=\(instance.displayName) (id=\(instance.id))")
            EventInstrumentation.log(
                action: "event_patch_success",
                eventId: response.data.id,
                eventName: response.data.name,
                instance: instance,
                metadata: ["status": response.data.status.rawValue]
            )
            return response.data
        } catch {
            consoleError("RemoteEventRepository: patchEvent failed for id=\(id) on instance=\(instance.displayName) (id=\(instance.id)) error=\(error.localizedDescription)")
            EventInstrumentation.error(
                action: "event_patch_failure",
                eventId: id,
                instance: instance,
                error: error,
                metadata: ["bodyType": String(describing: T.self)]
            )
            throw error
        }
    }

    private func upsert(_ event: Event, for instance: InstanceProfile) {
        var events = cache[instance.id] ?? []
        if let index = events.firstIndex(where: { $0.id == event.id }) {
            events[index] = event
        } else {
            events.append(event)
        }
        consoleLog("RemoteEventRepository: upserted event id=\(event.id) cacheCount(before set)=\(events.count)")
        cache[instance.id] = events
    }

    private func removeFromCache(id: String, instance: InstanceProfile) {
        guard var events = cache[instance.id] else {
            consoleLog("RemoteEventRepository: removeFromCache no cache for instance=\(instance.displayName) (id=\(instance.id))")
            return
        }
        let before = events.count
        events.removeAll { $0.id == id }
        let after = events.count
        consoleLog("RemoteEventRepository: removed event id=\(id) from cache. count before=\(before) after=\(after)")
        cache[instance.id] = events
    }

    private struct SchedulesResponse: Decodable { let data: [ScheduleDTO] }
    private struct ScheduleDTO: Decodable { let subdomain: String; let type: String? }

    private func resolveSubdomain(for instance: InstanceProfile) async throws -> (String, String?) {
        if let cached = subdomainCache[instance.id] { return (cached.subdomain, cached.type) }
        let response: SchedulesResponse = try await httpClient.request(
            "schedules",
            method: .get,
            query: ["per_page": "1000"],
            body: (nil as (any Encodable)?),
            instance: instance
        )
        guard let chosen = (response.data.first { ($0.type ?? "").lowercased() == "venue" } ?? response.data.first) else {
            throw APIError.serverError(statusCode: 0, message: "No schedules available for event creation")
        }
        subdomainCache[instance.id] = (subdomain: chosen.subdomain, type: chosen.type)
        return (chosen.subdomain, chosen.type)
    }

    private struct CreateEventDTO: Encodable {
        let id: String
        let name: String
        let description: String?
        let startsAt: String
        let endAt: String
        let durationMinutes: Int?
        let venueId: String?
        let roomId: String?
        let status: EventStatus
        let images: [URL]
        let capacity: Int?
        let ticketTypes: [TicketType]
        let publishState: PublishState
        let curatorId: String?
        let members: [String]
        let category: String?
        let groupSlug: String?
        let url: URL?

        enum CodingKeys: String, CodingKey {
            case id
            case name
            case description
            case startsAt = "starts_at"
            case endAt = "ends_at"
            case duration
            case venueId = "venue_id"
            case roomId = "room_id"
            case status
            case images
            case capacity
            case ticketTypes = "ticket_types"
            case publishState = "publish_state"
            case curatorId = "curator_role_id"
            case members
            case category
            case groupSlug = "group_slug"
            case url
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(id, forKey: .id)
            try container.encode(name, forKey: .name)
            try container.encodeIfPresent(description, forKey: .description)
            try container.encode(startsAt, forKey: .startsAt)
            try container.encode(endAt, forKey: .endAt)
            if let durationMinutes, durationMinutes > 0 {
                try container.encode(durationMinutes / 60, forKey: .duration)
            }
            if let venueId { try container.encode(venueId, forKey: .venueId) }
            try container.encodeIfPresent(roomId, forKey: .roomId)
            try container.encode(status, forKey: .status)
            try container.encode(images, forKey: .images)
            try container.encodeIfPresent(capacity, forKey: .capacity)
            try container.encode(ticketTypes, forKey: .ticketTypes)
            try container.encode(publishState, forKey: .publishState)
            try container.encodeIfPresent(curatorId, forKey: .curatorId)
            try container.encodeIfPresent(category, forKey: .category)
            try container.encodeIfPresent(groupSlug, forKey: .groupSlug)
            try container.encodeIfPresent(url, forKey: .url)
            if !members.isEmpty { try container.encode(members, forKey: .members) }
        }
    }

    private struct UpdateEventDTO: Encodable {
        let id: String?
        let name: String
        let description: String?
        let startsAt: String?
        let endAt: String?
        let durationMinutes: Int?
        let venueId: String?
        let roomId: String?
        let status: EventStatus
        let images: [URL]
        let capacity: Int?
        let ticketTypes: [TicketType]
        let publishState: PublishState
        let curatorId: String?
        let members: [String]
        let category: String?
        let groupSlug: String?
        let url: URL?

        enum CodingKeys: String, CodingKey {
            case id
            case name
            case description
            case startsAt = "starts_at"
            case endAt = "ends_at"
            case duration
            case venueId = "venue_id"
            case roomId = "room_id"
            case status
            case images
            case capacity
            case ticketTypes = "ticket_types"
            case publishState = "publish_state"
            case curatorId = "curator_role_id"
            case members
            case category
            case groupSlug = "group_slug"
            case url
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encodeIfPresent(id, forKey: .id)
            try container.encode(name, forKey: .name)
            try container.encodeIfPresent(description, forKey: .description)
            try container.encodeIfPresent(startsAt, forKey: .startsAt)
            try container.encodeIfPresent(endAt, forKey: .endAt)
            if let durationMinutes, durationMinutes > 0 {
                try container.encode(durationMinutes / 60, forKey: .duration)
            }
            if let venueId { try container.encode(venueId, forKey: .venueId) }
            try container.encodeIfPresent(roomId, forKey: .roomId)
            try container.encode(status, forKey: .status)
            try container.encode(images, forKey: .images)
            try container.encodeIfPresent(capacity, forKey: .capacity)
            try container.encode(ticketTypes, forKey: .ticketTypes)
            try container.encode(publishState, forKey: .publishState)
            try container.encodeIfPresent(curatorId, forKey: .curatorId)
            try container.encodeIfPresent(category, forKey: .category)
            try container.encodeIfPresent(groupSlug, forKey: .groupSlug)
            try container.encodeIfPresent(url, forKey: .url)
            if !members.isEmpty { try container.encode(members, forKey: .members) }
        }
    }
    
    private struct GenericEventResponse: Decodable { let data: Event }
}

