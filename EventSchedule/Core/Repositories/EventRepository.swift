import Foundation

@inline(__always)
private func consoleLog(_ message: String) {
    DebugLogger.log(message)
}

@inline(__always)
private func consoleError(_ message: String) {
    DebugLogger.error(message)
}

@inline(__always)
private func apiDateString(_ date: Date, timeZone: TimeZone) -> String {
    let formatter = Event.payloadDateFormatter(timeZone: timeZone)
    return formatter.string(from: date)
}

protocol EventRepository {
    func listEvents(for instance: InstanceProfile) async throws -> [Event]
    func getEvent(id: String, instance: InstanceProfile) async throws -> Event
    func listVenues(for instance: InstanceProfile) async throws -> [Venue]
    func listEventResources(for instance: InstanceProfile) async throws -> EventResources
    func createEvent(_ event: Event, instance: InstanceProfile, timeZoneOverride: TimeZone?, options: RemoteEventRepository.ExtendedEventOptions?) async throws -> Event
    func updateEvent(_ event: Event, instance: InstanceProfile, timeZoneOverride: TimeZone?, options: RemoteEventRepository.ExtendedEventOptions?) async throws -> Event
    func deleteEvent(id: String, instance: InstanceProfile) async throws
    func patchEvent<T: Encodable>(id: String, body: T, instance: InstanceProfile) async throws -> Event
    func uploadEventFlyer(eventId: String, imageData: Data, instance: InstanceProfile) async throws -> Event
}

extension EventRepository {
    func createEvent(_ event: Event, instance: InstanceProfile) async throws -> Event {
        try await createEvent(event, instance: instance, timeZoneOverride: nil, options: nil)
    }

    func updateEvent(_ event: Event, instance: InstanceProfile) async throws -> Event {
        try await updateEvent(event, instance: instance, timeZoneOverride: nil, options: nil)
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

        consoleError("EventListResponse: Unable to locate events array. CodingPath=\(decoder.codingPath.map { $0.stringValue }.joined(separator: ".")) attempted key: data")
        throw DecodingError.dataCorruptedError(
            forKey: .data,
            in: container,
            debugDescription: "No events array found in response"
        )
    }

    private enum CodingKeys: String, CodingKey {
        case data
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

        consoleError("EventDetailResponse: Unable to locate event object. CodingPath=\(decoder.codingPath.map { $0.stringValue }.joined(separator: ".")) attempted key: data")
        throw DecodingError.dataCorruptedError(
            forKey: .data,
            in: container,
            debugDescription: "No event object found in response"
        )
    }

    private enum CodingKeys: String, CodingKey {
        case data
    }
}

final class RemoteEventRepository: EventRepository {
    // Helper to extract category ID (integer) or nil if the value is a name
    private func extractCategoryId(_ category: String?) -> Int? {
        guard let cat = category, !cat.isEmpty else { return nil }
        return Int(cat)
    }
    
    // Helper to extract category name or nil if the value is numeric
    private func extractCategoryName(_ category: String?, explicitName: String?) -> String? {
        // If explicit name is provided, use it
        if let name = explicitName, !name.isEmpty {
            return name
        }
        // If category is not numeric, treat it as a name
        guard let cat = category, !cat.isEmpty else { return nil }
        if Int(cat) != nil {
            return nil // It's numeric, so not a name
        }
        return cat
    }
    
    // Normalize/whitelist payment method values expected by the backend.
    // If the provided value isn't recognized, return nil so we omit the field.
    private func normalizePaymentMethod(_ value: String?) -> String? {
        guard let raw = value?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else { return nil }
        let lower = raw.lowercased()
        // Whitelist of allowed values (adjust as backend evolves)
        let allowed: Set<String> = [
            "cash", "stripe", "invoiceninja"
        ]
        if allowed.contains(lower) { return lower }
        // Common synonyms mapping
        switch lower {
        case "credit", "debit", "card", "credit_card", "debit_card":
            // No direct support for generic card; backend expects a processor. Omit.
            return nil
        case "online", "online_payment", "web", "paypal", "square", "bank", "transfer", "bank_transfer", "ach":
            return nil
        default:
            return nil
        }
    }

    struct TicketDTO: Codable {
        let type: String?
        let price: Int
        let quantity: Int
        let description: String?
    }
    
    struct ExtendedEventOptions {
        var categoryName: String?
        var ticketsEnabled: Bool?
        var ticketCurrencyCode: String?
        var totalTicketsMode: String?
        var ticketNotes: String?
        var paymentMethod: String?
        var paymentInstructions: String?
        var expireUnpaidTickets: Bool?
        var remindUnpaidTicketsEvery: Int?
        var registrationUrl: URL?
        var eventPassword: String?
        var flyerImageId: String?
        var flyerImageData: Data?
        var clearFlyerImage: Bool?
        var guestListVisibility: String?
        var members: [MemberDTO]
        var schedule: String?
        var tickets: [TicketDTO]?
        var paymentUrl: String?
        
        init(
            categoryName: String? = nil,
            ticketsEnabled: Bool? = nil,
            ticketCurrencyCode: String? = nil,
            totalTicketsMode: String? = nil,
            ticketNotes: String? = nil,
            paymentMethod: String? = nil,
            paymentInstructions: String? = nil,
            expireUnpaidTickets: Bool? = nil,
            remindUnpaidTicketsEvery: Int? = nil,
            registrationUrl: URL? = nil,
            eventPassword: String? = nil,
            flyerImageId: String? = nil,
            flyerImageData: Data? = nil,
            clearFlyerImage: Bool? = nil,
            guestListVisibility: String? = nil,
            members: [MemberDTO] = [],
            schedule: String? = nil,
            tickets: [TicketDTO]? = nil,
            paymentUrl: String? = nil
        ) {
            self.categoryName = categoryName
            self.ticketsEnabled = ticketsEnabled
            self.ticketCurrencyCode = ticketCurrencyCode
            self.totalTicketsMode = totalTicketsMode
            self.ticketNotes = ticketNotes
            self.paymentMethod = paymentMethod
            self.paymentInstructions = paymentInstructions
            self.expireUnpaidTickets = expireUnpaidTickets
            self.remindUnpaidTicketsEvery = remindUnpaidTicketsEvery
            self.registrationUrl = registrationUrl
            self.eventPassword = eventPassword
            self.flyerImageId = flyerImageId
            self.flyerImageData = flyerImageData
            self.clearFlyerImage = clearFlyerImage
            self.guestListVisibility = guestListVisibility
            self.members = members
            self.schedule = schedule
            self.tickets = tickets
            self.paymentUrl = paymentUrl
        }
    }

    struct MemberDTO: Encodable {
        let name: String
        let email: String?
        let youtube_url: URL?
    }

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

    // Upload a flyer image and return its server-assigned image id
    private func uploadFlyer(_ data: Data, instance: InstanceProfile) async throws -> String {
        struct UploadResponse: Decodable { let id: String }
        // Assuming the backend accepts raw bytes or base64 via a dedicated endpoint.
        // If multipart is required, HTTPClientProtocol should provide that; for now, send as octet-stream.
        let response: UploadResponse = try await httpClient.request(
            "/api/events/flyers",
            method: .post,
            query: nil,
            body: data,
            instance: instance
        )
        return response.id
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
            if e.venueName == nil, let venueId = e.venueId, let name = map[venueId] {
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
        guard let venueId = event.venueId else { return event }
        var venues = venueCache[instance.id] ?? []
        if venues.isEmpty {
            if let res = try? await listEventResources(for: instance) {
                venues = res.venues.map { Venue(id: $0.id, name: $0.name) }
            }
        }
        if let name = venues.first(where: { $0.id == venueId })?.name {
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
                "/api/events",
                method: .get,
                query: nil,
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
        // Prefer cached event first
        if let cachedEvent = cache[instance.id]?.first(where: { $0.id == id }) {
            consoleLog("RemoteEventRepository: returning cached event id=\(id) for instance=\(instance.displayName) (id=\(instance.id))")
            return await enrichVenueName(cachedEvent, for: instance)
        }

        // Fallback to listing events and selecting the matching one
        do {
            let events = try await listEvents(for: instance)
            if let found = events.first(where: { $0.id == id }) {
                let enriched = await enrichVenueName(found, for: instance)
                upsert(enriched, for: instance)
                consoleLog("RemoteEventRepository: selected event from list id=\(enriched.id) for instance=\(instance.displayName) (id=\(instance.id))")
                return enriched
            }
            // Not found in list
            let error = NSError(domain: "RemoteEventRepository", code: 404, userInfo: [NSLocalizedDescriptionKey: "Event not found for id=\(id)"])
            throw error
        } catch {
            consoleError("RemoteEventRepository: getEvent selection failed for id=\(id) on instance=\(instance.displayName) (id=\(instance.id)) error=\(error.localizedDescription)")
            // If list retrieval fails, bubble up the error
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
                "/api/events/resources",
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
        timeZoneOverride: TimeZone? = nil,
        options: ExtendedEventOptions? = nil
    ) async throws -> Event {
        let (subdomain, scheduleType) = try await resolveSubdomain(for: instance)
        DebugLogger.log("RemoteEventRepository: creating under subdomain=\(subdomain) type=\(scheduleType ?? "<nil>")")
        let payloadTimeZone = timeZoneOverride ?? payloadTimeZoneProvider()
        
        let resources: EventResources
        if let cached = resourcesCache[instance.id] {
            resources = cached
        } else {
            resources = try await listEventResources(for: instance)
        }
        let validCuratorIds = Set(resources.curators.map { $0.id })
        let safeRoleId: String? = {
            guard let rid = event.curatorId?.trimmingCharacters(in: .whitespacesAndNewlines), !rid.isEmpty else { return nil }
            return validCuratorIds.contains(rid) ? rid : nil
        }()
        
        EventInstrumentation.log(
            action: "event_create_request",
            eventId: event.id,
            eventName: event.name,
            instance: instance,
            metadata: [
                "payloadTimeZone": payloadTimeZone.identifier,
                "hasOnlineUrl": String(event.onlineURL != nil)
            ]
        )
        let memberObjects = options?.members ?? []
        
        // Resolve flyer image id: prefer explicit id; else upload if data provided
        var resolvedFlyerId: String? = options?.flyerImageId
        if resolvedFlyerId == nil, let flyerData = options?.flyerImageData {
            do {
                resolvedFlyerId = try await uploadFlyer(flyerData, instance: instance)
                DebugLogger.log("RemoteEventRepository: uploaded flyer, received id=\(resolvedFlyerId ?? "nil")")
            } catch {
                DebugLogger.error("RemoteEventRepository: flyer upload failed: \(error.localizedDescription)")
                // Proceed without flyer if upload fails
            }
        }
        
        // Determine venue fields
        let hasVenue = event.venueId != nil && !event.venueId!.isEmpty
        let venueIdValue = hasVenue ? event.venueId : nil
        
        // Convert eventUrl to String (send empty string if nil for backend compatibility)
        let eventUrlString: String? = event.onlineURL?.absoluteString ?? ""
        
        // Never send venue_address1 - it creates unwanted venues
        // Backend requires at least one of: venue_id or event_url
        let venueAddress1Value: String? = nil
        
        let dto = CreateEventDTO(
            id: event.id,
            name: event.name,
            description: event.description,
            startsAt: apiDateString(event.startAt, timeZone: payloadTimeZone),
            endAt: apiDateString(event.endAt, timeZone: payloadTimeZone),
            durationMinutes: event.durationMinutes,
            timezone: payloadTimeZone.identifier,
            venueId: venueIdValue,
            venueAddress1: venueAddress1Value,
            roomId: event.roomId,
            images: event.images,
            capacity: event.capacity,
            ticketTypes: event.ticketTypes,
            publishState: event.publishState,
            roleId: safeRoleId,
            showGuestList: event.attendeesVisible,
            categoryId: extractCategoryId(event.category),
            eventUrl: eventUrlString,
            attendeesVisible: event.attendeesVisible,
            isRecurring: event.isRecurring,
            categoryName: extractCategoryName(event.category, explicitName: options?.categoryName),
            ticketsEnabled: options?.ticketsEnabled,
            ticketCurrencyCode: options?.ticketCurrencyCode,
            totalTicketsMode: options?.totalTicketsMode,
            ticketNotes: options?.ticketNotes,
            paymentMethod: normalizePaymentMethod(options?.paymentMethod),
            paymentInstructions: options?.paymentInstructions,
            expireUnpaidTickets: options?.expireUnpaidTickets,
            remindUnpaidTicketsEvery: options?.remindUnpaidTicketsEvery,
            registrationUrl: options?.registrationUrl,
            eventPassword: options?.eventPassword,
            flyerImageId: resolvedFlyerId,
            guestListVisibility: options?.guestListVisibility,
            members: memberObjects,
            schedule: options?.schedule,
            tickets: options?.tickets,
            paymentUrl: options?.paymentUrl
        )
        do {
            let response: EventDetailResponse = try await httpClient.request(
                "/api/events/\(subdomain)",
                method: .post,
                query: nil,
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
                    "venueId": enriched.venueId ?? "nil"
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
        timeZoneOverride: TimeZone? = nil,
        options: ExtendedEventOptions? = nil
    ) async throws -> Event {
        do {
            // A: Always refresh resources to avoid stale role/venue data
            let resources: EventResources = try await listEventResources(for: instance)
            let validVenueIds = Set(resources.venues.map { $0.id })
            let safeVenueId: String?
            if let venueId = event.venueId, !venueId.isEmpty {
                // Validate venue ID against available venues
                safeVenueId = validVenueIds.contains(venueId) ? venueId : nil
            } else {
                // Explicit nil for online-only events
                safeVenueId = nil
            }
            // members and talent filtering removed per instructions

            let safeMembers: [MemberDTO] = options?.members ?? []

            // Determine incoming and previous role ids
            let previousCuratorId: String? = cache[instance.id]?.first(where: { $0.id == event.id })?.curatorId
            let incomingCuratorId: String? = event.curatorId?.trimmingCharacters(in: .whitespacesAndNewlines)

            // Backend does not accept role_id on update (see SQL error). Omit the key entirely.
            let resolvedRoleId: String?? = .none

            let payloadTimeZone = timeZoneOverride ?? payloadTimeZoneProvider()
            // API accepts seconds precision; adding a single second prevents the service
            // from applying the 5-hour drift observed when an update payload uses the
            // exact start/end values returned by previous reads.
            let adjustedStart = event.startAt.addingTimeInterval(1)
            let adjustedEnd = event.endAt.addingTimeInterval(1)
            
            // Resolve flyer image id for update
            var resolvedFlyerId: String? = options?.flyerImageId
            if resolvedFlyerId == nil, let flyerData = options?.flyerImageData {
                do {
                    resolvedFlyerId = try await uploadFlyer(flyerData, instance: instance)
                    DebugLogger.log("RemoteEventRepository: uploaded flyer, received id=\(resolvedFlyerId ?? "nil")")
                } catch {
                    DebugLogger.error("RemoteEventRepository: flyer upload failed: \(error.localizedDescription)")
                }
            }
            
            // Convert eventUrl to String - send empty string when nil to try to clear the field
            let eventUrlString: String? = event.onlineURL?.absoluteString ?? ""
            
            // Never send venue_address1 - it creates unwanted venues
            // Backend requires at least one of: venue_id or event_url
            let venueAddress1Value: String? = nil
            
            DebugLogger.log("RemoteEventRepository update DTO values: venueId=\(safeVenueId ?? "nil") venueAddress1=\(venueAddress1Value ?? "nil") eventUrl=\(eventUrlString ?? "nil")")
            
            let dto = UpdateEventDTO(
                id: event.id,
                name: event.name,
                description: event.description,
                startsAt: apiDateString(adjustedStart, timeZone: payloadTimeZone),
                endAt: apiDateString(adjustedEnd, timeZone: payloadTimeZone),
                durationMinutes: event.durationMinutes,
                timezone: payloadTimeZone.identifier,
                venueId: safeVenueId,
                venueAddress1: venueAddress1Value,
                roomId: event.roomId,
                images: event.images,
                capacity: event.capacity,
                ticketTypes: event.ticketTypes,
                publishState: event.publishState,
                roleId: resolvedRoleId,
                showGuestList: event.attendeesVisible,
                categoryId: extractCategoryId(event.category),
                eventUrl: eventUrlString,
                attendeesVisible: event.attendeesVisible,
                isRecurring: event.isRecurring,
                categoryName: extractCategoryName(event.category, explicitName: options?.categoryName),
                ticketsEnabled: options?.ticketsEnabled,
                ticketCurrencyCode: options?.ticketCurrencyCode,
                totalTicketsMode: options?.totalTicketsMode,
                ticketNotes: options?.ticketNotes,
                paymentMethod: normalizePaymentMethod(options?.paymentMethod),
                paymentInstructions: options?.paymentInstructions,
                expireUnpaidTickets: options?.expireUnpaidTickets,
                remindUnpaidTicketsEvery: options?.remindUnpaidTicketsEvery,
                registrationUrl: options?.registrationUrl,
                eventPassword: options?.eventPassword,
                flyerImageId: resolvedFlyerId != nil ? .some(resolvedFlyerId) : nil,
                flyerImageUrl: (options?.clearFlyerImage == true) ? .some(nil) : (event.flyerImageUrl != nil ? .some(event.flyerImageUrl) : nil),
                guestListVisibility: options?.guestListVisibility,
                members: safeMembers,
                schedule: options?.schedule,
                tickets: options?.tickets,
                paymentUrl: options?.paymentUrl
            )
            // Debug: Log the actual JSON payload
            if let jsonData = try? JSONEncoder().encode(dto),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                DebugLogger.log("RemoteEventRepository update JSON payload: \(jsonString)")
            }
            
            EventInstrumentation.log(
                action: "event_update_request",
                eventId: event.id,
                eventName: event.name,
                instance: instance,
                metadata: [
                    "payloadTimeZone": payloadTimeZone.identifier,
                    "incomingCuratorId": incomingCuratorId ?? "nil",
                    "previousCuratorId": previousCuratorId ?? "nil",
                    "sendingRoleKey": "false",
                    "sendingRoleValue": "omit",
                    "dto_venueId": dto.venueId ?? "null",
                    "dto_venueAddress1": dto.venueAddress1 ?? "null",
                    "dto_eventUrl": dto.eventUrl ?? "null"
                ]
            )
            let response: EventDetailResponse = try await httpClient.request(
                "/api/events/\(event.id)",
                method: .patch,
                query: nil,
                body: dto,
                instance: instance
            )
            var enriched = await enrichVenueName(response.event, for: instance)
            
            // Backend bug workaround: Backend doesn't clear fields when we send null/empty
            // Manually override the returned event with our intended values
            if safeVenueId == nil && enriched.venueId != nil {
                DebugLogger.log("Backend didn't clear venueId, manually clearing it")
                enriched.venueId = nil
            }
            if eventUrlString == "" && enriched.onlineURL != nil {
                DebugLogger.log("Backend didn't clear onlineURL, manually clearing it")
                enriched.onlineURL = nil
            }
            
            upsert(enriched, for: instance)
            consoleLog("RemoteEventRepository: updated event id=\(enriched.id) for instance=\(instance.displayName) (id=\(instance.id))")
            DebugLogger.log("Server returned after update: venueId=\(enriched.venueId ?? "nil") eventUrl=\(enriched.onlineURL?.absoluteString ?? "nil")")
            EventInstrumentation.log(
                action: "event_update_success",
                eventId: enriched.id,
                eventName: enriched.name,
                instance: instance,
                metadata: [
                    "publishState": enriched.publishState.rawValue,
                    "returned_venueId": enriched.venueId ?? "null",
                    "returned_eventUrl": enriched.onlineURL?.absoluteString ?? "null"
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
                "/api/events/\(id)",
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
                "/api/events/\(id)",
                method: .patch,
                query: nil,
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
                metadata: [:]
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
    
    func uploadEventFlyer(eventId: String, imageData: Data, instance: InstanceProfile) async throws -> Event {
        // Upload to dedicated endpoint: POST /api/events/flyer/{event_id}
        let boundary = UUID().uuidString
        var body = Data()
        
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"image\"; filename=\"flyer.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        
        let uploadURL = instance.baseURL.appendingPathComponent("events/flyer/\(eventId)")
        var uploadRequest = URLRequest(url: uploadURL)
        uploadRequest.httpMethod = "POST"
        uploadRequest.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        uploadRequest.httpBody = body
        
        if let token = AuthTokenStore.shared.token(for: instance) {
            uploadRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        } else if let apiKey = APIKeyStore.shared.load(for: instance) {
            uploadRequest.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        }
        
        consoleLog("uploadEventFlyer: Uploading to events/flyer/\(eventId), full URL: \(uploadURL.absoluteString)")
        let (uploadData, uploadResponse) = try await URLSession.shared.data(for: uploadRequest)
        
        guard let httpUploadResponse = uploadResponse as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        guard (200...299).contains(httpUploadResponse.statusCode) else {
            let errorMsg = String(data: uploadData, encoding: .utf8) ?? "No response body"
            consoleError("uploadEventFlyer: Upload failed \(httpUploadResponse.statusCode): \(errorMsg)")
            throw NSError(domain: "EventRepository", code: httpUploadResponse.statusCode, userInfo: [
                NSLocalizedDescriptionKey: "Failed to upload flyer",
                NSLocalizedFailureReasonErrorKey: errorMsg
            ])
        }
        
        // Parse response: {"data": event.toApiData(), "meta": {"message": "..."}}
        struct FlyerResponse: Decodable {
            let data: Event
            let meta: Meta
            
            struct Meta: Decodable {
                let message: String
            }
        }
        
        // Log raw response for debugging - search for flyer fields
        if let responseString = String(data: uploadData, encoding: .utf8) {
            consoleLog("uploadEventFlyer: Raw response length: \(responseString.count) characters")
            consoleLog("uploadEventFlyer: FULL raw response: \(responseString)")
            
            // Check if flyer fields exist anywhere in response and extract their values
            let hasImageUrl = responseString.contains("flyer_image_url")
            let hasImageId = responseString.contains("flyer_image_id")
            consoleLog("uploadEventFlyer: Response contains 'flyer_image_url': \(hasImageUrl)")
            consoleLog("uploadEventFlyer: Response contains 'flyer_image_id': \(hasImageId)")
            
            // Extract the actual JSON values using regex
            if hasImageUrl {
                let pattern = "\"flyer_image_url\"\\s*:\\s*([^,}\\]]+)"
                if let regex = try? NSRegularExpression(pattern: pattern, options: []),
                   let match = regex.firstMatch(in: responseString, options: [], range: NSRange(responseString.startIndex..., in: responseString)),
                   let valueRange = Range(match.range(at: 1), in: responseString) {
                    let value = String(responseString[valueRange]).trimmingCharacters(in: .whitespaces)
                    consoleLog("uploadEventFlyer: flyer_image_url value in JSON: \(value)")
                }
            }
            
            if hasImageId {
                let pattern = "\"flyer_image_id\"\\s*:\\s*([^,}\\]]+)"
                if let regex = try? NSRegularExpression(pattern: pattern, options: []),
                   let match = regex.firstMatch(in: responseString, options: [], range: NSRange(responseString.startIndex..., in: responseString)),
                   let valueRange = Range(match.range(at: 1), in: responseString) {
                    let value = String(responseString[valueRange]).trimmingCharacters(in: .whitespaces)
                    consoleLog("uploadEventFlyer: flyer_image_id value in JSON: \(value)")
                }
            }
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        
        let response = try decoder.decode(FlyerResponse.self, from: uploadData)
        consoleLog("uploadEventFlyer: \(response.meta.message)")
        consoleLog("uploadEventFlyer: Decoded event flyerImageUrl=\(response.data.flyerImageUrl ?? "nil") flyerImageId=\(response.data.flyerImageId?.description ?? "nil")")
        consoleLog("uploadEventFlyer: Decoded event id=\(response.data.id) name=\(response.data.name)")
        
        // Try to manually parse just the flyer fields to verify they can be decoded
        if let jsonDict = try? JSONSerialization.jsonObject(with: uploadData) as? [String: Any],
           let dataDict = jsonDict["data"] as? [String: Any] {
            let rawFlyerUrl = dataDict["flyer_image_url"]
            let rawFlyerId = dataDict["flyer_image_id"]
            consoleLog("uploadEventFlyer: RAW from dict - flyer_image_url: \(String(describing: rawFlyerUrl))")
            consoleLog("uploadEventFlyer: RAW from dict - flyer_image_id: \(String(describing: rawFlyerId))")
        }
        
        // Update cache
        upsert(response.data, for: instance)
        
        return response.data
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
            "/api/schedules",
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
        let timezone: String
        let venueId: String?
        let venueAddress1: String?
        let roomId: String?
        let images: [URL]
        let capacity: Int?
        let ticketTypes: [TicketType]
        let publishState: PublishState
        let roleId: String?
        let showGuestList: Bool?
        let categoryId: Int?
        let eventUrl: String? // Changed to String to allow sending empty string
        let attendeesVisible: Bool?
        let isRecurring: Bool?

        let categoryName: String?
        let ticketsEnabled: Bool?
        let ticketCurrencyCode: String?
        let totalTicketsMode: String?
        let ticketNotes: String?
        let paymentMethod: String?
        let paymentInstructions: String?
        let expireUnpaidTickets: Bool?
        let remindUnpaidTicketsEvery: Int?
        let registrationUrl: URL?
        let eventPassword: String?
        let flyerImageId: String?
        let guestListVisibility: String?
        let members: [MemberDTO]
        let schedule: String?
        let tickets: [TicketDTO]?
        let paymentUrl: String?

        enum CodingKeys: String, CodingKey {
            case id
            case name
            case description
            case startsAt = "starts_at"
            case endAt = "ends_at"
            case duration
            case timezone
            case venueId = "venue_id"
            case venueAddress1 = "venue_address1"
            case roomId = "room_id"
            case images
            case capacity
            case ticketTypes = "ticket_types"
            case publishState = "publish_state"
            case roleId = "role_id"
            case showGuestList = "show_guest_list"
            case categoryId = "category_id"
            case eventUrl = "event_url"
            case attendeesVisible = "attendees_visible"
            case isRecurring = "is_recurring"

            case categoryName = "category_name"
            case ticketsEnabled = "tickets_enabled"
            case ticketCurrencyCode = "ticket_currency_code"
            case totalTicketsMode = "total_tickets_mode"
            case ticketNotes = "ticket_notes"
            case paymentMethod = "payment_method"
            case paymentInstructions = "payment_instructions"
            case expireUnpaidTickets = "expire_unpaid_tickets"
            case remindUnpaidTicketsEvery = "remind_unpaid_tickets_every"
            case registrationUrl = "registration_url"
            case eventPassword = "event_password"
            case flyerImageId = "flyer_image_id"
            case guestListVisibility = "guest_list_visibility"
            case members = "members"
            case schedule = "schedule"
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
            try container.encode(timezone, forKey: .timezone)
            // Always encode venue fields including null to satisfy backend validation
            if let venueId { try container.encode(venueId, forKey: .venueId) }
            try container.encode(venueAddress1, forKey: .venueAddress1)
            try container.encodeIfPresent(roomId, forKey: .roomId)
            try container.encode(images, forKey: .images)
            try container.encodeIfPresent(capacity, forKey: .capacity)
            try container.encode(ticketTypes, forKey: .ticketTypes)
            try container.encode(publishState, forKey: .publishState)
            try container.encodeIfPresent(roleId, forKey: .roleId)
            try container.encodeIfPresent(showGuestList, forKey: .showGuestList)
            try container.encodeIfPresent(categoryId, forKey: .categoryId)
            // Always encode event_url - will send empty string to clear, or actual URL string
            try container.encode(eventUrl, forKey: .eventUrl)
            try container.encodeIfPresent(attendeesVisible, forKey: .attendeesVisible)
            try container.encodeIfPresent(isRecurring, forKey: .isRecurring)

            try container.encodeIfPresent(categoryName, forKey: .categoryName)
            try container.encodeIfPresent(ticketsEnabled, forKey: .ticketsEnabled)
            try container.encodeIfPresent(ticketCurrencyCode, forKey: .ticketCurrencyCode)
            try container.encodeIfPresent(totalTicketsMode, forKey: .totalTicketsMode)
            try container.encodeIfPresent(ticketNotes, forKey: .ticketNotes)
            try container.encodeIfPresent(paymentMethod, forKey: .paymentMethod)
            try container.encodeIfPresent(paymentInstructions, forKey: .paymentInstructions)
            try container.encodeIfPresent(expireUnpaidTickets, forKey: .expireUnpaidTickets)
            try container.encodeIfPresent(remindUnpaidTicketsEvery, forKey: .remindUnpaidTicketsEvery)
            try container.encodeIfPresent(registrationUrl, forKey: .registrationUrl)
            try container.encodeIfPresent(eventPassword, forKey: .eventPassword)
            try container.encodeIfPresent(flyerImageId, forKey: .flyerImageId)
            try container.encodeIfPresent(guestListVisibility, forKey: .guestListVisibility)
            if !members.isEmpty {
                try container.encode(members, forKey: .members)
            }
            try container.encodeIfPresent(schedule, forKey: .schedule)
        }
    }

    private struct UpdateEventDTO: Encodable {
        let id: String?
        let name: String
        let description: String?
        let startsAt: String?
        let endAt: String?
        let durationMinutes: Int?
        let timezone: String
        let venueId: String?
        let venueAddress1: String?
        let roomId: String?
        let images: [URL]
        let capacity: Int?
        let ticketTypes: [TicketType]
        let publishState: PublishState
        let roleId: String?? // Double-optional to support explicit null encoding
        let showGuestList: Bool?
        let categoryId: Int?
        let eventUrl: String? // Changed to String to allow sending empty string to clear
        let attendeesVisible: Bool?
        let isRecurring: Bool?

        let categoryName: String?
        let ticketsEnabled: Bool?
        let ticketCurrencyCode: String?
        let totalTicketsMode: String?
        let ticketNotes: String?
        let paymentMethod: String?
        let paymentInstructions: String?
        let expireUnpaidTickets: Bool?
        let remindUnpaidTicketsEvery: Int?
        let registrationUrl: URL?
        let eventPassword: String?
        let flyerImageId: String?? // Double-optional to support explicit null for removal
        let flyerImageUrl: String?? // Double-optional to support explicit null for removal
        let guestListVisibility: String?
        let members: [MemberDTO]
        let schedule: String?
        let tickets: [TicketDTO]?
        let paymentUrl: String?

        enum CodingKeys: String, CodingKey {
            case id
            case name
            case description
            case startsAt = "starts_at"
            case endAt = "ends_at"
            case duration
            case timezone
            case venueId = "venue_id"
            case venueAddress1 = "venue_address1"
            case roomId = "room_id"
            case images
            case capacity
            case ticketTypes = "ticket_types"
            case publishState = "publish_state"
            case roleId = "role_id"
            case showGuestList = "show_guest_list"
            case categoryId = "category_id"
            case eventUrl = "event_url"
            case attendeesVisible = "attendees_visible"
            case isRecurring = "is_recurring"

            case categoryName = "category_name"
            case ticketsEnabled = "tickets_enabled"
            case ticketCurrencyCode = "ticket_currency_code"
            case totalTicketsMode = "total_tickets_mode"
            case ticketNotes = "ticket_notes"
            case paymentMethod = "payment_method"
            case paymentInstructions = "payment_instructions"
            case expireUnpaidTickets = "expire_unpaid_tickets"
            case remindUnpaidTicketsEvery = "remind_unpaid_tickets_every"
            case registrationUrl = "registration_url"
            case eventPassword = "event_password"
            case flyerImageId = "flyer_image_id"
            case flyerImageUrl = "flyer_image_url"
            case guestListVisibility = "guest_list_visibility"
            case members = "members"
            case schedule = "schedule"
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
            try container.encode(timezone, forKey: .timezone)
            // Always encode venueId, venueAddress1, and eventUrl - including null values
            // The backend requires at least one of: venue_id, venue_address1, or event_url
            try container.encode(venueId, forKey: .venueId)
            try container.encode(venueAddress1, forKey: .venueAddress1)
            try container.encodeIfPresent(roomId, forKey: .roomId)
            try container.encode(images, forKey: .images)
            try container.encodeIfPresent(capacity, forKey: .capacity)
            try container.encode(ticketTypes, forKey: .ticketTypes)
            try container.encode(publishState, forKey: .publishState)

            // Encode role_id with explicit null support. If roleId is .none, omit the key.
            // If roleId is .some(nil), encode explicit null. If .some(.some(value)), encode the value.
            if let roleId = roleId {
                try container.encode(roleId, forKey: .roleId) // roleId is String?
            }

            try container.encodeIfPresent(showGuestList, forKey: .showGuestList)
            try container.encodeIfPresent(categoryId, forKey: .categoryId)
            // Always encode event_url including null for proper validation
            try container.encode(eventUrl, forKey: .eventUrl)
            try container.encodeIfPresent(attendeesVisible, forKey: .attendeesVisible)
            try container.encodeIfPresent(isRecurring, forKey: .isRecurring)

            try container.encodeIfPresent(categoryName, forKey: .categoryName)
            try container.encodeIfPresent(ticketsEnabled, forKey: .ticketsEnabled)
            try container.encodeIfPresent(ticketCurrencyCode, forKey: .ticketCurrencyCode)
            try container.encodeIfPresent(totalTicketsMode, forKey: .totalTicketsMode)
            try container.encodeIfPresent(ticketNotes, forKey: .ticketNotes)
            try container.encodeIfPresent(paymentMethod, forKey: .paymentMethod)
            try container.encodeIfPresent(paymentInstructions, forKey: .paymentInstructions)
            try container.encodeIfPresent(expireUnpaidTickets, forKey: .expireUnpaidTickets)
            try container.encodeIfPresent(remindUnpaidTicketsEvery, forKey: .remindUnpaidTicketsEvery)
            try container.encodeIfPresent(registrationUrl, forKey: .registrationUrl)
            try container.encodeIfPresent(eventPassword, forKey: .eventPassword)
            // Encode flyer fields with explicit null support for removal
            if let flyerImageId = flyerImageId {
                try container.encode(flyerImageId, forKey: .flyerImageId)
            }
            if let flyerImageUrl = flyerImageUrl {
                try container.encode(flyerImageUrl, forKey: .flyerImageUrl)
            }
            try container.encodeIfPresent(guestListVisibility, forKey: .guestListVisibility)
            if !members.isEmpty {
                try container.encode(members, forKey: .members)
            }
            try container.encodeIfPresent(schedule, forKey: .schedule)
        }
    }
    
    private struct GenericEventResponse: Decodable { let data: Event }
}

