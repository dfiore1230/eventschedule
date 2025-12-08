import Foundation

protocol EventRepository {
    func listEvents(for instance: InstanceProfile) async throws -> [Event]
    func getEvent(id: String, instance: InstanceProfile) async throws -> Event
    func createEvent(_ event: Event, instance: InstanceProfile) async throws -> Event
    func updateEvent(_ event: Event, instance: InstanceProfile) async throws -> Event
    func deleteEvent(id: String, instance: InstanceProfile) async throws
}

final class RemoteEventRepository: EventRepository {
    private let httpClient: HTTPClientProtocol
    private var cache: [UUID: [Event]] = [:]

    init(httpClient: HTTPClientProtocol = HTTPClient()) {
        self.httpClient = httpClient
    }

    func listEvents(for instance: InstanceProfile) async throws -> [Event] {
        do {
            let events: [Event] = try await httpClient.request(
                "/api/events",
                method: .get,
                query: ["include": "venue,talent,tickets"],
                body: Optional<Event>.none,
                instance: instance
            )
            cache[instance.id] = events
            return events
        } catch {
            if let cached = cache[instance.id] {
                return cached
            }
            throw error
        }
    }

    func getEvent(id: String, instance: InstanceProfile) async throws -> Event {
        do {
            let event: Event = try await httpClient.request(
                "/api/events/\(id)",
                method: .get,
                query: ["include": "venue,talent,tickets"],
                body: Optional<Event>.none,
                instance: instance
            )
            upsert(event, for: instance)
            return event
        } catch {
            if let cachedEvent = cache[instance.id]?.first(where: { $0.id == id }) {
                return cachedEvent
            }
            throw error
        }
    }

    func createEvent(_ event: Event, instance: InstanceProfile) async throws -> Event {
        let created: Event = try await httpClient.request(
            "/api/events",
            method: .post,
            query: ["include": "venue,talent,tickets"],
            body: event,
            instance: instance
        )
        upsert(created, for: instance)
        return created
    }

    func updateEvent(_ event: Event, instance: InstanceProfile) async throws -> Event {
        let updated: Event = try await httpClient.request(
            "/api/events/\(event.id)",
            method: .put,
            query: ["include": "venue,talent,tickets"],
            body: event,
            instance: instance
        )
        upsert(updated, for: instance)
        return updated
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
