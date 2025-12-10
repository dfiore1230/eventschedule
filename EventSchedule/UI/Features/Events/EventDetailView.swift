import SwiftUI

struct EventDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appSettings: AppSettings

    @State private var event: Event
    @State private var isEditing: Bool = false
    @State private var isPerformingAction: Bool = false
    @State private var actionError: String?
    @State private var showingDeleteConfirm: Bool = false

    private let repository: EventRepository
    private let instance: InstanceProfile
    private let onSave: ((Event) -> Void)?
    private let onDelete: ((Event) -> Void)?

    init(event: Event, repository: EventRepository, instance: InstanceProfile, onSave: ((Event) -> Void)? = nil, onDelete: ((Event) -> Void)? = nil) {
        self.repository = repository
        self.instance = instance
        self.onSave = onSave
        self.onDelete = onDelete
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
                if let category = event.category, !category.isEmpty {
                    Label(category, systemImage: "tag")
                        .foregroundColor(.secondary)
                }
                if let group = event.groupSlug, !group.isEmpty {
                    Label("Pick list: \(group)", systemImage: "list.bullet")
                        .foregroundColor(.secondary)
                }
            }

            Section(header: Text("When")) {
                HStack {
                    Label("Starts", systemImage: "clock")
                    Spacer()
                    Text(event.formattedDateTime(event.startAt))
                }
                HStack {
                    Label("Ends", systemImage: "clock.fill")
                    Spacer()
                    Text(event.formattedDateTime(event.endAt))
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

            if let onlineURL = event.onlineURL {
                Section(header: Text("Online")) {
                    Link(destination: onlineURL) {
                        Label(onlineURL.absoluteString, systemImage: "link")
                            .lineLimit(1)
                            .truncationMode(.middle)
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
                Button(role: .destructive) {
                    showingDeleteConfirm = true
                } label: {
                    Label("Delete event", systemImage: "trash")
                }
                .disabled(isPerformingAction)
                .alert("Delete Event", isPresented: $showingDeleteConfirm) {
                    Button("Delete", role: .destructive) { Task { await deleteEvent() } }
                    Button("Cancel", role: .cancel) { }
                } message: {
                    Text("This action cannot be undone.")
                }

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
                Button("Edit") {
                    isEditing = true
                }
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
        .tint(.accentColor)
    }

    private struct ActionPatchDTO: Encodable {
        var status: String?
    }

    private func apiString(for status: EventStatus) -> String {
        switch status {
        case .scheduled: return "scheduled"
        case .ongoing: return "ongoing"
        case .completed: return "completed"
        case .cancelled: return "cancelled"
        }
    }

    private func updateStatus(target: EventStatus) async {
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

        do {
            let updated = transform(event)
            var dto = ActionPatchDTO()
            if updated.status != event.status {
                dto.status = apiString(for: updated.status)
            }
            // If nothing changed, bail out
            if dto.status == nil {
                await MainActor.run { isPerformingAction = false }
                return
            }
            let saved = try await repository.patchEvent(id: event.id, body: dto, instance: instance)
            await MainActor.run {
                event = saved
                onSave?(saved)
                isPerformingAction = false
            }
        } catch {
            await MainActor.run {
                actionError = error.localizedDescription
                isPerformingAction = false
            }
        }
    }

    private func deleteEvent() async {
        guard !isPerformingAction else { return }
        isPerformingAction = true
        actionError = nil
        do {
            try await repository.deleteEvent(id: event.id, instance: instance)
            await MainActor.run {
                onDelete?(event)
                dismiss()
                isPerformingAction = false
            }
        } catch {
            await MainActor.run {
                actionError = error.localizedDescription
                isPerformingAction = false
            }
        }
    }

    private func archiveEvent() async {
        guard !isPerformingAction else { return }
        isPerformingAction = true
        actionError = nil
        struct ArchiveDTO: Encodable { let publish_state: String }
        do {
            let saved = try await repository.patchEvent(id: event.id, body: ArchiveDTO(publish_state: "archived"), instance: instance)
            await MainActor.run {
                event = saved
                onSave?(saved)
                isPerformingAction = false
            }
        } catch {
            await MainActor.run {
                actionError = error.localizedDescription
                isPerformingAction = false
            }
        }
    }
}
