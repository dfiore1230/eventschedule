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
        print("EventsListViewModel: context set with instance=\(instance.displayName) (id=\(instance.id))")
    }

    func load() async {
        guard let repository, let instance else {
            errorMessage = "No instance selected."
            print("EventsListViewModel: load aborted – no repository or instance available")
            return
        }

        print("EventsListViewModel: starting load for instance=\(instance.displayName) (id=\(instance.id))")
        isLoading = true
        defer { isLoading = false }

        do {
            let events = try await repository.listEvents(for: instance)
            self.events = events
            errorMessage = nil
            print("EventsListViewModel: load succeeded – received \(events.count) events")
        } catch {
            errorMessage = error.localizedDescription
            print("EventsListViewModel: load failed with error=\(error.localizedDescription)")
        }
    }

    func refresh() async {
        print("EventsListViewModel: refresh requested")
        await load()
    }

    func remove(at offsets: IndexSet) async {
        guard let repository, let instance else { return }
        let idsToDelete = offsets.compactMap { events[safe: $0]?.id }

        for id in idsToDelete {
            do {
                print("EventsListViewModel: attempting to delete event id=\(id)")
                try await repository.deleteEvent(id: id, instance: instance)
                events.removeAll { $0.id == id }
                print("EventsListViewModel: deleted event id=\(id)")
            } catch {
                errorMessage = error.localizedDescription
                print("EventsListViewModel: failed to delete event id=\(id) error=\(error.localizedDescription)")
            }
        }
    }

    func apply(event: Event) {
        if let index = events.firstIndex(where: { $0.id == event.id }) {
            events[index] = event
            print("EventsListViewModel: updated existing event id=\(event.id)")
        } else {
            events.append(event)
            print("EventsListViewModel: appended new event id=\(event.id)")
        }
    }
}

private extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
