import Foundation

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

            if let deeperData = try nestedData.nestedContainer(keyedBy: NestedCodingKeys.self, forKey: .data),
               let deepItems = try deeperData.decodeIfPresent([Event].self, forKey: .items) {
                events = deepItems
                return
            }
        }

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
            return response.events
        } catch {
            DebugLogger.error("RemoteEventRepository: listEvents failed for instance=\(instance.displayName) (id=\(instance.id)) error=\(error.localizedDescription)")
            if let cached = cache[instance.id] {
                DebugLogger.log("RemoteEventRepository: returning \(cached.count) cached events after list failure for instance=\(instance.displayName) (id=\(instance.id))")
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
            return response.event
        } catch {
            DebugLogger.error("RemoteEventRepository: getEvent failed for id=\(id) on instance=\(instance.displayName) (id=\(instance.id)) error=\(error.localizedDescription)")
            if let cachedEvent = cache[instance.id]?.first(where: { $0.id == id }) {
                DebugLogger.log("RemoteEventRepository: returning cached event id=\(id) after fetch failure on instance=\(instance.displayName) (id=\(instance.id))")
                return cachedEvent
            }
            throw error
        }
    }

    func createEvent(_ event: Event, instance: InstanceProfile) async throws -> Event {
        let response: EventDetailResponse = try await httpClient.request(
            "/api/events",
            method: .post,
            query: ["include": "venue,talent,tickets"],
            body: event,
            instance: instance
        )
        upsert(response.event, for: instance)
        return response.event
    }

    func updateEvent(_ event: Event, instance: InstanceProfile) async throws -> Event {
        let response: EventDetailResponse = try await httpClient.request(
            "/api/events/\(event.id)",
            method: .put,
            query: ["include": "venue,talent,tickets"],
            body: event,
            instance: instance
        )
        upsert(response.event, for: instance)
        return response.event
    }

    func deleteEvent(id: String, instance: InstanceProfile) async throws {
        try await httpClient.requestVoid(
            "/api/events/\(id)",
            method: .delete,
            query: nil,
            body: Optional<Event>.none,
            instance: instance
        )
        removeFromCache(id: id, instance: instance)
    }

    private func upsert(_ event: Event, for instance: InstanceProfile) {
        var events = cache[instance.id] ?? []
        if let index = events.firstIndex(where: { $0.id == event.id }) {
            events[index] = event
        } else {
            events.append(event)
        }
        cache[instance.id] = events
    }

    private func removeFromCache(id: String, instance: InstanceProfile) {
        guard var events = cache[instance.id] else { return }
        events.removeAll { $0.id == id }
        cache[instance.id] = events
    }
}
