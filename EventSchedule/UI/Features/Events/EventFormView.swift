import SwiftUI
import UIKit

struct EventFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme
    @Environment(\.httpClient) private var httpClient

    private let repository: EventRepository
    private let instance: InstanceProfile
    private let onSave: ((Event) -> Void)?

    @State private var name: String
    @State private var description: String
    @State private var startAtLocal: Date
    @State private var endAtLocal: Date
    @State private var venueId: String
    @State private var venueName: String?
    @State private var venueTimeZoneIdentifier: String? = nil
    @State private var userTimeZoneIdentifier: String? = nil
    @State private var eventTimeZoneIdentifier: String? = nil
    private var currentEditingTimeZone: TimeZone {
        if let id = eventTimeZoneIdentifier, let tz = TimeZone(identifier: id) { return tz }
        if let id = venueTimeZoneIdentifier, let tz = TimeZone(identifier: id) { return tz }
        if let id = userTimeZoneIdentifier, let tz = TimeZone(identifier: id) { return tz }
        return .current
    }
    @State private var availableVenues: [Venue] = []
    @State private var availableCurators: [EventRole] = []
    @State private var availableTalent: [EventRole] = []
    @State private var isLoadingVenues: Bool = false
    @State private var venueErrorMessage: String?
    @State private var roomId: String
    @State private var status: EventStatus
    @State private var capacity: String
    @State private var talentSelections: Set<String> = []
    @State private var curatorSelections: Set<String> = []
    @State private var curatorsModified: Bool = false

    // Batch 1: Event type toggles
    @State private var isInPerson: Bool = true
    @State private var isOnline: Bool = false

    // Batch 1: Venue mode (existing vs new)
    private enum VenueMode: String, CaseIterable { case existing = "Existing", newVenue = "New" }
    @State private var venueMode: VenueMode = .existing

    // New venue fields
    @State private var newVenueName: String = ""
    @State private var newVenueEmail: String = ""
    @State private var newVenueAddress1: String = ""
    @State private var newVenueAddress2: String = ""
    @State private var newVenueCity: String = ""
    @State private var newVenueState: String = ""
    @State private var newVenuePostal: String = ""
    @State private var newVenueCountry: String = ""

    // Venue search
    @State private var isSearchingVenues: Bool = false
    @State private var venueSearchResults: [Venue] = []

    // Participants sourcing
    private enum ParticipantMode: String, CaseIterable { case existing = "Existing", newMember = "New" }
    @State private var participantMode: ParticipantMode = .existing
    @State private var newParticipantName: String = ""
    @State private var newParticipantEmail: String = ""
    @State private var newParticipantYouTube: String = ""
    @State private var addedParticipants: [EventRole] = []
    @State private var participantsModified: Bool = false

    // Details
    @State private var durationHours: String = ""
    @State private var selectedCategory: String = ""
    @State private var selectedGroupSlug: String = ""

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
        _startAtLocal = State(initialValue: event?.startAt ?? Date())
        _endAtLocal = State(initialValue: event?.endAt ?? Date().addingTimeInterval(3600))
        _venueId = State(initialValue: event?.venueId ?? "")
        _venueName = State(initialValue: nil)
        _talentSelections = State(initialValue: [])
        _roomId = State(initialValue: event?.roomId ?? "")
        _status = State(initialValue: event?.status ?? .scheduled)
        _capacity = State(initialValue: event?.capacity.map { String($0) } ?? "")
        _durationHours = State(initialValue: event?.durationMinutes.map { String($0 / 60) } ?? "")

        if let evt = event {
            // If Event exposes a timezone string from primary schedule, set it here
            let mirror = Mirror(reflecting: evt)
            if let tz = mirror.children.first(where: { $0.label == "timezone" })?.value as? String, !tz.isEmpty {
                _eventTimeZoneIdentifier = State(initialValue: tz)
            }
        }
    }
    
    var body: some View {
        Form {
            Section(header: Text("Details")) {
                TextField("Name", text: $name)
                if originalEvent != nil {
                    HStack {
                        Text("Link")
                        Spacer()
                        let base = webBaseURL(for: instance)
                        let linkString = base.appendingPathComponent("events").appendingPathComponent(originalEvent?.id ?? "").absoluteString
                        Text(linkString)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Button("Copy Link") { copyEventLink() }
                    }
                }
                if !selectedGroupSlug.isEmpty {
                    Text("Group: \(selectedGroupSlug)")
                }
                if !selectedCategory.isEmpty {
                    Text("Category: \(selectedCategory)")
                }
                DatePicker("Start", selection: $startAtLocal)
                TextField("Duration (hours)", text: $durationHours)
                    .keyboardType(.decimalPad)
                TextField("Description", text: $description, axis: .vertical)
                    .lineLimit(3...5)
            }

            Section(header: Text("Type")) {
                Toggle("In-person", isOn: $isInPerson)
                Toggle("Online", isOn: $isOnline)
                if !isInPerson && !isOnline {
                    Text("At least one type must be selected.")
                        .font(.footnote)
                        .foregroundColor(.red)
                }
            }

            Section(header: Text("Location")) {
                Picker("Venue Mode", selection: $venueMode) {
                    Text(VenueMode.existing.rawValue).tag(VenueMode.existing)
                    Text("New").tag(VenueMode.newVenue)
                }
                .pickerStyle(.segmented)

                if venueMode == .existing {
                    if isLoadingVenues {
                        ProgressView("Loading venues…")
                    }
                    if !availableVenues.isEmpty {
                        Picker("Venue", selection: $venueId) {
                            ForEach(availableVenues) { venue in
                                Text(venue.name).tag(venue.id)
                            }
                        }
                        .onChange(of: venueId) { _ in
                            venueTimeZoneIdentifier = nil
                        }
                    } else {
                        Text("No venues available. Add a venue in the web app, then refresh.")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                    TextField("Room ID", text: $roomId)
                } else {
                    Group {
                        TextField("Venue Name", text: $newVenueName)
                        HStack {
                            TextField("Venue Email", text: $newVenueEmail)
                                .textInputAutocapitalization(.never)
                                .keyboardType(.emailAddress)
                            Button("Search") { Task { await searchVenuesByEmail() } }
                                .disabled(newVenueEmail.isEmpty || isSearchingVenues)
                        }
                        if isSearchingVenues { ProgressView() }
                        if !venueSearchResults.isEmpty {
                            Picker("Search Results", selection: $venueId) {
                                ForEach(venueSearchResults) { v in
                                    Text(v.name).tag(v.id)
                                }
                            }
                        }
                        TextField("Address 1", text: $newVenueAddress1)
                        TextField("Address 2", text: $newVenueAddress2)
                        TextField("City", text: $newVenueCity)
                        TextField("State/Province", text: $newVenueState)
                        TextField("Postal Code", text: $newVenuePostal)
                        TextField("Country Code (e.g., US)", text: $newVenueCountry)
                        HStack {
                            Button("View map") { openInMaps() }
                            Spacer()
                            Button("Validate address") { /* placeholder */ }
                            Button("Done") { applyNewVenueSelection() }
                                .disabled(newVenueName.isEmpty && venueId.isEmpty)
                        }
                    }
                }

                if let venueErrorMessage {
                    Text(venueErrorMessage)
                        .font(.footnote)
                        .foregroundColor(.red)
                }
            }

            Section(header: Text("Participants")) {
                Picker("Mode", selection: $participantMode) {
                    Text(ParticipantMode.existing.rawValue).tag(ParticipantMode.existing)
                    Text("New").tag(ParticipantMode.newMember)
                }
                .pickerStyle(.segmented)

                if participantMode == .existing {
                    if !availableTalent.isEmpty {
                        ForEach(availableTalent) { talent in
                            Toggle(isOn: Binding(
                                get: { talentSelections.contains(talent.id) },
                                set: { isOn in
                                    if isOn { talentSelections.insert(talent.id) } else { talentSelections.remove(talent.id) }
                                    participantsModified = true
                                }
                            )) { Text(talent.name) }
                        }
                    } else {
                        Text("No known participants.")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                } else {
                    TextField("Name", text: $newParticipantName)
                    TextField("Email (optional)", text: $newParticipantEmail)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                    TextField("YouTube URL (optional)", text: $newParticipantYouTube)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                    Button("Add") { addNewParticipant() }
                        .disabled(newParticipantName.isEmpty)
                    if !addedParticipants.isEmpty {
                        VStack(alignment: .leading) {
                            Text("To add:").font(.subheadline)
                            ForEach(addedParticipants) { p in
                                Text("• \(p.name)")
                            }
                        }
                    }
                }
            }
            
            Section(header: Text("Curators")) {
                if !availableCurators.isEmpty {
                    ForEach(availableCurators) { curator in
                        Toggle(isOn: Binding(
                            get: { curatorSelections.contains(curator.id) },
                            set: { isOn in
                                if isOn { curatorSelections.insert(curator.id) } else { curatorSelections.remove(curator.id) }
                                curatorsModified = true
                            }
                        )) { Text(curator.name) }
                    }
                } else {
                    Text("No curators available.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }

            Section(header: Text("Status")) {
                Picker("Event Status", selection: $status) {
                    Text("Scheduled").tag(EventStatus.scheduled)
                    Text("Ongoing").tag(EventStatus.ongoing)
                    Text("Completed").tag(EventStatus.completed)
                    Text("Cancelled").tag(EventStatus.cancelled)
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
                .disabled(isSaving || name.isEmpty || venueId.isEmpty || (availableVenues.isEmpty && venueMode == .existing) || (!isInPerson && !isOnline))
            }
        }
        .task { await loadResources() }
        .accentColor(theme.accent)
    }

    private func apiDateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = currentEditingTimeZone
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: date)
    }
    
    private func isSignificantlyDifferent(_ a: Date, _ b: Date, toleranceSeconds: TimeInterval = 1) -> Bool {
        return abs(a.timeIntervalSince1970 - b.timeIntervalSince1970) > toleranceSeconds
    }

    private func apiString(for status: EventStatus) -> String {
        switch status {
        case .scheduled: return "scheduled"
        case .ongoing: return "ongoing"
        case .completed: return "completed"
        case .cancelled: return "cancelled"
        }
    }
    
    private struct EventPatchDTO: Encodable {
        var name: String?
        var description: String?
        var starts_at: String?
        var ends_at: String?
        var room_id: String??
        var status: String?
        var capacity: Int??
        var venue_id: String?
        var venue_name: String?
        var venue_address1: String?
        var venue_address2: String?
        var venue_city: String?
        var venue_state: String?
        var venue_postal: String?
        var venue_country: String?
        var members: [MemberPatch]?
        var curators: [CuratorPatch]?

        struct MemberPatch: Encodable {
            var id: String?
            var name: String?
            var email: String?
            var youtube_url: String?
        }
        struct CuratorPatch: Encodable {
            var id: String
        }
    }

    private func save() {
        guard !isSaving else { return }
        isSaving = true
        errorMessage = nil

        DebugLogger.log("EventFormView: save started for \(originalEvent == nil ? "new" : "existing") event on instance=\(instance.displayName) (id=\(instance.id))")

        Task {
            do {
                if originalEvent == nil {
                    let validTalentIds: [String] = availableTalent
                        .map { $0.id }
                        .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                        .filter { talentSelections.contains($0) }

                    let parsedDurationMinutes: Int?
                    if let durationValue = Double(durationHours.trimmingCharacters(in: .whitespacesAndNewlines)), durationValue > 0 {
                        parsedDurationMinutes = Int(durationValue * 60)
                    } else {
                        parsedDurationMinutes = nil
                    }

                    let computedEndAt: Date
                    if let parsedDurationMinutes, parsedDurationMinutes > 0 {
                        computedEndAt = startAtLocal.addingTimeInterval(TimeInterval(parsedDurationMinutes * 60))
                    } else {
                        computedEndAt = endAtLocal
                    }

                    let payload = Event(
                        id: UUID().uuidString,
                        name: name,
                        description: description.isEmpty ? nil : description,
                        startAt: startAtLocal,
                        endAt: computedEndAt,
                        durationMinutes: parsedDurationMinutes,
                        venueId: venueId,
                        roomId: roomId.isEmpty ? nil : roomId,
                        status: status,
                        images: [],
                        capacity: Int(capacity),
                        ticketTypes: [],
                        curatorId: curatorSelections.first,
                        talentIds: validTalentIds
                    )

                    DebugLogger.log("EventFormView: attempting to create event id=\(payload.id)")

                    let savedEvent = try await repository.createEvent(payload, instance: instance)

                    await MainActor.run {
                        onSave?(savedEvent)
                        dismiss()
                    }

                    DebugLogger.log("EventFormView: save finished for event id=\(savedEvent.id)")
                } else {
                    var dto = EventPatchDTO()

                    if name != originalEvent!.name { dto.name = name }
                    if description != (originalEvent!.description ?? "") {
                        dto.description = description.isEmpty ? nil : description
                    }
                    if isSignificantlyDifferent(startAtLocal, originalEvent!.startAt) {
                        dto.starts_at = apiDateString(startAtLocal)
                    }
                    if isSignificantlyDifferent(endAtLocal, originalEvent!.endAt) {
                        dto.ends_at = apiDateString(endAtLocal)
                    }
                    let trimmedRoom = roomId.trimmingCharacters(in: .whitespacesAndNewlines)
                    let originalRoomTrimmed = originalEvent!.roomId?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    if trimmedRoom != originalRoomTrimmed {
                        dto.room_id = trimmedRoom.isEmpty ? .some(nil) : .some(trimmedRoom)
                    }
                    if status != originalEvent!.status { dto.status = apiString(for: status) }
                    let originalCapacityStr = originalEvent!.capacity.map { String($0) } ?? ""
                    if capacity != originalCapacityStr {
                        if let capInt = Int(capacity) { dto.capacity = .some(capInt) } else { dto.capacity = .some(nil) }
                    }
                    if venueMode == .existing {
                        if venueId != originalEvent!.venueId && !venueId.isEmpty { dto.venue_id = venueId }
                    } else {
                        if let _ = venueSearchResults.first(where: { $0.id == venueId }) {
                            dto.venue_id = venueId
                        } else {
                            if !newVenueName.isEmpty { dto.venue_name = newVenueName }
                            if !newVenueAddress1.isEmpty { dto.venue_address1 = newVenueAddress1 }
                            if !newVenueAddress2.isEmpty { dto.venue_address2 = newVenueAddress2 }
                            if !newVenueCity.isEmpty { dto.venue_city = newVenueCity }
                            if !newVenueState.isEmpty { dto.venue_state = newVenueState }
                            if !newVenuePostal.isEmpty { dto.venue_postal = newVenuePostal }
                            if !newVenueCountry.isEmpty { dto.venue_country = newVenueCountry }
                        }
                    }
                    if participantsModified {
                        var members: [EventPatchDTO.MemberPatch] = []
                        let validTalentIds: [String] = availableTalent
                            .map { $0.id }
                            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                            .filter { talentSelections.contains($0) }
                        members.append(contentsOf: validTalentIds.map { .init(id: $0, name: nil, email: nil, youtube_url: nil) })
                        for p in addedParticipants {
                            members.append(.init(id: nil, name: p.name, email: nil, youtube_url: nil))
                        }
                        if !members.isEmpty { dto.members = members }
                    }
                    if curatorsModified {
                        let selectedCuratorIds = availableCurators
                            .map { $0.id }
                            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                            .filter { curatorSelections.contains($0) }
                        dto.curators = selectedCuratorIds.map { EventPatchDTO.CuratorPatch(id: $0) }
                    }

                    let savedEvent = try await repository.patchEvent(id: originalEvent!.id, body: dto, instance: instance)

                    await MainActor.run {
                        onSave?(savedEvent)
                        dismiss()
                    }

                    DebugLogger.log("EventFormView: save finished for event id=\(savedEvent.id)")
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isSaving = false
                }

                DebugLogger.error("EventFormView: save failed with error=\(error.localizedDescription)")
            }
        }
    }

    private func loadResources() async {
        guard !isLoadingVenues else { return }
        guard availableVenues.isEmpty else { return }

        isLoadingVenues = true
        venueErrorMessage = nil

        do {
            let resources = try await repository.listEventResources(for: instance)
            await MainActor.run {
                availableVenues = resources.venues.map { Venue(id: $0.id, name: $0.name) }

                availableCurators = resources.curators
                availableTalent = resources.talent

                if let existingCurator = originalEvent?.curatorId, resources.curators.contains(where: { $0.id == existingCurator }) {
                    curatorSelections = [existingCurator]
                }

                if availableVenues.isEmpty {
                    venueId = ""
                    venueName = nil
                } else if venueId.isEmpty, let firstVenue = availableVenues.first {
                    venueId = firstVenue.id
                    venueName = firstVenue.name
                } else if let selected = availableVenues.first(where: { $0.id == venueId }) {
                    venueName = selected.name
                } else {
                    venueId = ""
                    venueName = nil
                }

                // Attempt to set venue timezone from resources if exposed
                venueTimeZoneIdentifier = nil
            }
        } catch {
            await MainActor.run {
                venueErrorMessage = error.localizedDescription
            }
        }

        await MainActor.run {
            isLoadingVenues = false
        }
    }

    private func openInMaps() {
        let address = [newVenueAddress1, newVenueAddress2, newVenueCity, newVenueState, newVenuePostal, newVenueCountry]
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
        guard !address.isEmpty, let encoded = address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed), let url = URL(string: "http://maps.apple.com/?q=\(encoded)") else { return }
        UIApplication.shared.open(url)
    }

    private func applyNewVenueSelection() {
        // Prefer selected search result if present, else synthesize a local venue id/name pair
        if let selected = venueSearchResults.first(where: { $0.id == venueId }) {
            venueName = selected.name
            venueMode = .existing
            return
        }
        if !newVenueName.isEmpty {
            venueName = newVenueName
            // Keep venueId empty when creating under a venue subdomain; repository omits venue_id accordingly
            venueMode = .existing
        }
    }

    private func addNewParticipant() {
        let temp = EventRole(id: UUID().uuidString, name: newParticipantName, type: "talent")
        addedParticipants.append(temp)
        participantsModified = true
        newParticipantName = ""
        newParticipantEmail = ""
        newParticipantYouTube = ""
    }

    private func copyEventLink() {
        let pasteboard = UIPasteboard.general
        if let id = originalEvent?.id {
            let url = webBaseURL(for: instance).appendingPathComponent("events").appendingPathComponent(id)
            pasteboard.string = url.absoluteString
        } else {
            pasteboard.string = nil
        }
    }

    private func webBaseURL(for instance: InstanceProfile) -> URL {
        guard var components = URLComponents(url: instance.baseURL, resolvingAgainstBaseURL: false) else {
            return instance.baseURL.deletingLastPathComponent()
        }

        if components.path.hasSuffix("/api") {
            let newPath = String(components.path.dropLast(4))
            components.path = newPath
        }

        return components.url ?? instance.baseURL.deletingLastPathComponent()
    }

    private func searchVenuesByEmail() async {
        guard !newVenueEmail.isEmpty else { return }
        isSearchingVenues = true
        do {
            // Reuse existing repository listVenues with name filter if available via resources; otherwise, call roles endpoint via HTTPClient
            let query = ["type": "venue", "name": newVenueEmail, "per_page": "10"]
            let path = "roles"
            struct RolesResponse: Decodable { let data: [RoleDTO] }
            struct RoleDTO: Decodable { let id: String; let name: String }
            let response: RolesResponse = try await httpClient.request(path, method: .get, query: query, body: (nil as (any Encodable)?), instance: self.instance)
            await MainActor.run {
                self.venueSearchResults = response.data.map { Venue(id: $0.id, name: $0.name) }
            }
        } catch {
            await MainActor.run {
                self.venueSearchResults = []
            }
        }
        await MainActor.run { self.isSearchingVenues = false }
    }
}
