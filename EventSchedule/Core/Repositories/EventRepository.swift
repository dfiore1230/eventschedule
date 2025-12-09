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

protocol EventRepository {
    func listEvents(for instance: InstanceProfile) async throws -> [Event]
    func getEvent(id: String, instance: InstanceProfile) async throws -> Event
    func createEvent(_ event: Event, instance: InstanceProfile) async throws -> Event
    func updateEvent(_ event: Event, instance: InstanceProfile) async throws -> Event
    func deleteEvent(id: String, instance: InstanceProfile) async throws
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
    private var cache: [UUID: [Event]] = [:]

    init(httpClient: HTTPClientProtocol = HTTPClient()) {
        self.httpClient = httpClient
    }

    func listEvents(for instance: InstanceProfile) async throws -> [Event] {
        do {
            let response: EventListResponse = try await httpClient.request(
                "/api/events",
                method: .get,
                query: ["include": "venue,talent,tickets"],
                body: Optional<Event>.none,
                instance: instance
            )
            cache[instance.id] = response.events
            consoleLog("RemoteEventRepository: fetched \(response.events.count) events for instance=\(instance.displayName) (id=\(instance.id))")
            return response.events
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
                "/api/events/\(id)",
                method: .get,
                query: ["include": "venue,talent,tickets"],
                body: Optional<Event>.none,
                instance: instance
            )
            upsert(response.event, for: instance)
            consoleLog("RemoteEventRepository: fetched event id=\(response.event.id) for instance=\(instance.displayName) (id=\(instance.id))")
            return response.event
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

    func createEvent(_ event: Event, instance: InstanceProfile) async throws -> Event {
        do {
            let response: EventDetailResponse = try await httpClient.request(
                "/api/events",
                method: .post,
                query: ["include": "venue,talent,tickets"],
                body: event,
                instance: instance
            )
            upsert(response.event, for: instance)
            consoleLog("RemoteEventRepository: created event id=\(response.event.id) for instance=\(instance.displayName) (id=\(instance.id))")
            return response.event
        } catch {
            consoleError("RemoteEventRepository: createEvent failed on instance=\(instance.displayName) (id=\(instance.id)) error=\(error.localizedDescription)")
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

    func updateEvent(_ event: Event, instance: InstanceProfile) async throws -> Event {
        do {
            let response: EventDetailResponse = try await httpClient.request(
                "/api/events/\(event.id)",
                method: .put,
                query: ["include": "venue,talent,tickets"],
                body: event,
                instance: instance
            )
            upsert(response.event, for: instance)
            consoleLog("RemoteEventRepository: updated event id=\(response.event.id) for instance=\(instance.displayName) (id=\(instance.id))")
            return response.event
        } catch {
            consoleError("RemoteEventRepository: updateEvent failed for id=\(event.id) on instance=\(instance.displayName) (id=\(instance.id)) error=\(error.localizedDescription)")
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
}

