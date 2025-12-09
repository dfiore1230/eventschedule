import SwiftUI

struct EventDetailView: View {
    @Environment(\.theme) private var theme

    @State private var event: Event
    @State private var isEditing: Bool = false
    @State private var isPerformingAction: Bool = false
    @State private var actionError: String?

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
                if event.endAt > event.startAt {
                    let minutes = Int(event.endAt.timeIntervalSince(event.startAt) / 60)
                    HStack {
                        Label("Duration", systemImage: "timer")
                        Spacer()
                        Text("\(minutes) minutes")
                            .foregroundColor(.secondary)
                    }
                }
            }

            Section(header: Text("Location")) {
                HStack {
                    Label("Venue", systemImage: "building.2")
                    Spacer()
                    Text(event.venueDisplayDescription)
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
                    StatusBadge(title: event.status.rawValue.capitalized, style: .status(event.status))
                }
                HStack {
                    Label("Publish", systemImage: "globe")
                    Spacer()
                    StatusBadge(title: event.publishState.rawValue.capitalized, style: .publish(event.publishState))
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

            if !event.ticketTypes.isEmpty {
                Section(header: Text("Tickets")) {
                    ForEach(event.ticketTypes) { ticket in
                        HStack {
                            Text(ticket.name)
                            Spacer()
                            if let price = ticket.price, let currency = ticket.currency {
                                let display = "\(currency) \(price)"
                                Text(verbatim: display)
                                    .foregroundColor(.secondary)
                            } else {
                                Text("Free")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }

            Section(header: Text("Quick actions")) {
                Button {
                    Task { await updatePublishState(target: event.publishState == .published ? .draft : .published) }
                } label: {
                    Label(event.publishState == .published ? "Unpublish" : "Publish", systemImage: event.publishState == .published ? "eye.slash" : "globe")
                }
                .disabled(isPerformingAction)

                HStack {
                    Button {
                        Task { await updateStatus(target: .ongoing) }
                    } label: {
                        Label("Start now", systemImage: "play.circle")
                    }
                    .disabled(isPerformingAction || event.status == .ongoing)

                    Spacer()

                    Button {
                        Task { await updateStatus(target: .completed) }
                    } label: {
                        Label("Mark done", systemImage: "checkmark.circle")
                    }
                    .disabled(isPerformingAction || event.status == .completed)
                }

                Button(role: .destructive) {
                    Task { await updateStatus(target: .cancelled) }
                } label: {
                    Label("Cancel event", systemImage: "xmark.octagon")
                }
                .disabled(isPerformingAction || event.status == .cancelled)

                if let actionError {
                    Text(actionError)
                        .font(.footnote)
                        .foregroundColor(.red)
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

    private func updatePublishState(target: PublishState) async {
        DebugLogger.log("EventDetailView: requested publish state change to \(target.rawValue) for event id=\(event.id)")
        await updateEvent { current in
            var updated = current
            updated.publishState = target
            return updated
        }
    }

    private func updateStatus(target: EventStatus) async {
        DebugLogger.log("EventDetailView: requested status change to \(target.rawValue) for event id=\(event.id)")
        await updateEvent { current in
            var updated = current
            updated.status = target
            return updated
        }
    }

    private func updateEvent(transform: (Event) -> Event) async {
        guard !isPerformingAction else { return }
        isPerformingAction = true
        actionError = nil

        DebugLogger.log("EventDetailView: performing update for event id=\(event.id)")

        do {
            let updated = transform(event)
            let saved = try await repository.updateEvent(updated, instance: instance)
            await MainActor.run {
                event = saved
                onSave?(saved)
                isPerformingAction = false
            }

            DebugLogger.log("EventDetailView: update succeeded for event id=\(event.id)")
        } catch {
            await MainActor.run {
                actionError = error.localizedDescription
                isPerformingAction = false
            }

            DebugLogger.error("EventDetailView: update failed for event id=\(event.id) error=\(error.localizedDescription)")
        }
    }
}

