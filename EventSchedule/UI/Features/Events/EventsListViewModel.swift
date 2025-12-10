import Foundation
import Combine

@MainActor
final class EventsListViewModel: ObservableObject {
    @Published var events: [Event] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private var repository: EventRepository?
    private var instance: InstanceProfile?

    func setContext(repository: EventRepository, instance: InstanceProfile) {
        self.repository = repository
        self.instance = instance
    }

    func load() async {
        guard let repository, let instance else {
            errorMessage = "No instance selected."
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let events = try await repository.listEvents(for: instance)
            self.events = events
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func refresh() async {
        await load()
    }

    func remove(at offsets: IndexSet) async {
        guard let repository, let instance else { return }
        let idsToDelete = offsets.compactMap { events[safe: $0]?.id }

        for id in idsToDelete {
            do {
                try await repository.deleteEvent(id: id, instance: instance)
                events.removeAll { $0.id == id }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func apply(event: Event) {
        if let index = events.firstIndex(where: { $0.id == event.id }) {
            events[index] = event
        } else {
            events.append(event)
        }
    }

    func remove(id: String) {
        events.removeAll { $0.id == id }
    }
}

private extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
