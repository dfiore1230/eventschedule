import SwiftUI

struct EventFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme

    private let repository: EventRepository
    private let instance: InstanceProfile
    private let onSave: ((Event) -> Void)?

    @State private var name: String
    @State private var description: String
    @State private var startAt: Date
    @State private var endAt: Date
    @State private var venueId: String
    @State private var roomId: String
    @State private var status: EventStatus
    @State private var publishState: PublishState
    @State private var capacity: String

    @State private var isSaving: Bool = false
    @State private var errorMessage: String?

    private let originalEvent: Event?

    init(event: Event? = nil, repository: EventRepository, instance: InstanceProfile, onSave: ((Event) -> Void)? = nil) {
        self.repository = repository
        self.instance = instance
        self.onSave = onSave
        self.originalEvent = event

        _name = State(initialValue: event?.name ?? "")
        _description = State(initialValue: event?.description ?? "")
        _startAt = State(initialValue: event?.startAt ?? Date())
        _endAt = State(initialValue: event?.endAt ?? Date().addingTimeInterval(3600))
        _venueId = State(initialValue: event?.venueId ?? "")
        _roomId = State(initialValue: event?.roomId ?? "")
        _status = State(initialValue: event?.status ?? .scheduled)
        _publishState = State(initialValue: event?.publishState ?? .draft)
        _capacity = State(initialValue: event?.capacity.map { String($0) } ?? "")
    }

    var body: some View {
        Form {
            Section(header: Text("Details")) {
                TextField("Name", text: $name)
                TextField("Description", text: $description, axis: .vertical)
                    .lineLimit(3...5)
            }

            Section(header: Text("Schedule")) {
                DatePicker("Start", selection: $startAt)
                DatePicker("End", selection: $endAt)
            }

            Section(header: Text("Location")) {
                TextField("Venue ID", text: $venueId)
                TextField("Room ID", text: $roomId)
            }

            Section(header: Text("Status")) {
                Picker("Event Status", selection: $status) {
                    Text("Scheduled").tag(EventStatus.scheduled)
                    Text("Ongoing").tag(EventStatus.ongoing)
                    Text("Completed").tag(EventStatus.completed)
                    Text("Cancelled").tag(EventStatus.cancelled)
                }
                Picker("Publish State", selection: $publishState) {
                    Text("Draft").tag(PublishState.draft)
                    Text("Published").tag(PublishState.published)
                    Text("Archived").tag(PublishState.archived)
                }
                TextField("Capacity", text: $capacity)
                    .keyboardType(.numberPad)
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundColor(.red)
                }
            }
        }
        .navigationTitle(originalEvent == nil ? "New Event" : "Edit Event")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(action: save) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Text("Save")
                    }
                }
                .disabled(isSaving || name.isEmpty || venueId.isEmpty)
            }
        }
        .accentColor(theme.accent)
    }

    private func save() {
        guard !isSaving else { return }
        isSaving = true
        errorMessage = nil

        Task {
            do {
                let capacityValue = Int(capacity)
                let durationMinutes = max(0, Int(endAt.timeIntervalSince(startAt) / 60))
                let payload = Event(
                    id: originalEvent?.id ?? UUID().uuidString,
                    name: name,
                    description: description.isEmpty ? nil : description,
                    startAt: startAt,
                    endAt: endAt,
                    durationMinutes: durationMinutes,
                    venueId: venueId,
                    roomId: roomId.isEmpty ? nil : roomId,
                    status: status,
                    images: originalEvent?.images ?? [],
                    capacity: capacityValue,
                    ticketTypes: originalEvent?.ticketTypes ?? [],
                    publishState: publishState
                )

                let savedEvent: Event
                if originalEvent == nil {
                    savedEvent = try await repository.createEvent(payload, instance: instance)
                } else {
                    savedEvent = try await repository.updateEvent(payload, instance: instance)
                }

                await MainActor.run {
                    onSave?(savedEvent)
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isSaving = false
                }
            }
        }
    }
}
