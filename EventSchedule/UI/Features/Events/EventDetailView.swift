import SwiftUI

struct EventDetailView: View {
    @Environment(\.theme) private var theme

    @State private var event: Event
    @State private var isEditing: Bool = false

    private let repository: EventRepository
    private let instance: InstanceProfile
    private let onSave: ((Event) -> Void)?

    init(event: Event, repository: EventRepository, instance: InstanceProfile, onSave: ((Event) -> Void)? = nil) {
        self.repository = repository
        self.instance = instance
        self.onSave = onSave
        _event = State(initialValue: event)
    }

    var body: some View {
        Form {
            Section(header: Text("Details")) {
                Text(event.name)
                    .font(.title3)
                    .bold()
                if let description = event.description, !description.isEmpty {
                    Text(description)
                }
            }

            Section(header: Text("When")) {
                HStack {
                    Label("Starts", systemImage: "clock")
                    Spacer()
                    Text(event.startAt.formatted(date: .abbreviated, time: .shortened))
                        .foregroundColor(.secondary)
                }
                HStack {
                    Label("Ends", systemImage: "clock.fill")
                    Spacer()
                    Text(event.endAt.formatted(date: .abbreviated, time: .shortened))
                        .foregroundColor(.secondary)
                }
                if let duration = event.durationMinutes {
                    HStack {
                        Label("Duration", systemImage: "timer")
                        Spacer()
                        Text("\(duration) minutes")
                            .foregroundColor(.secondary)
                    }
                }
            }

            Section(header: Text("Location")) {
                HStack {
                    Label("Venue", systemImage: "building.2")
                    Spacer()
                    Text(event.venueId.isEmpty ? "Unknown" : event.venueId)
                        .foregroundColor(.secondary)
                }
                if let roomId = event.roomId {
                    HStack {
                        Label("Room", systemImage: "door.left.hand.open")
                        Spacer()
                        Text(roomId)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Section(header: Text("Status")) {
                HStack {
                    Label("Event", systemImage: "bolt.horizontal.fill")
                    Spacer()
                    Text(event.status.rawValue.capitalized)
                        .foregroundColor(.secondary)
                }
                HStack {
                    Label("Publish", systemImage: "globe")
                    Spacer()
                    Text(event.publishState.rawValue.capitalized)
                        .foregroundColor(.secondary)
                }
                if let capacity = event.capacity {
                    HStack {
                        Label("Capacity", systemImage: "person.3")
                        Spacer()
                        Text(String(capacity))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Event")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Edit") { isEditing = true }
            }
        }
        .sheet(isPresented: $isEditing) {
            NavigationStack {
                EventFormView(
                    event: event,
                    repository: repository,
                    instance: instance
                ) { updated in
                    self.event = updated
                    onSave?(updated)
                }
            }
        }
        .accentColor(theme.accent)
    }
}
