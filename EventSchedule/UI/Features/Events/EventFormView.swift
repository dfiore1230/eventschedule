import SwiftUI
import PhotosUI
import UIKit

struct EventFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme
    @Environment(\.httpClient) private var httpClient
    @EnvironmentObject private var appSettings: AppSettings

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
    @State private var availableVenues: [Venue] = []
    @State private var availableCurators: [EventRole] = []
    @State private var availableTalent: [EventRole] = []
    @State private var isLoadingVenues: Bool = false
    @State private var venueErrorMessage: String?
    @State private var roomId: String
    @State private var capacity: String
    @State private var talentSelections: Set<String> = []
    @State private var curatorSelections: Set<String> = []
    @State private var curatorsModified: Bool = false

    // Batch 1: Event type toggles
    @State private var isInPerson: Bool = true
    @State private var isOnline: Bool = false

    @State private var participantsModified: Bool = false

    // Details
    @State private var durationHours: String = ""
    @State private var selectedCategory: String = ""
    @State private var selectedGroupSlug: String = ""
    @State private var onlineURL: String = ""
    @State private var isRecurring: Bool = false
    @State private var attendeesVisible: Bool = true
    @State private var availableCategories: [String] = []
    @State private var availableGroups: [EventGroup] = []
    @State private var imageURLs: [URL] = []
    @State private var flierSelection: [PhotosPickerItem] = []
    @State private var ticketDrafts: [TicketDraft] = []

    @State private var isSaving: Bool = false
    @State private var errorMessage: String?
    @State private var startWasModified: Bool = false
    @State private var durationWasModified: Bool = false

    private let originalEvent: Event?
    private let initialDurationHours: String
    private var initialStartComponents: DateComponents?
    private let editingTimeZone: TimeZone

    private var currentEditingTimeZone: TimeZone { editingTimeZone }

    init(event: Event? = nil, repository: EventRepository, instance: InstanceProfile, onSave: ((Event) -> Void)? = nil) {
        self.repository = repository
        self.instance = instance
        self.onSave = onSave
        self.originalEvent = event
        self.initialDurationHours = Self.durationHoursString(from: event?.durationMinutes)

        // Convert server UTC dates into the event's local wall time for editing
        func convertUTCDate(_ date: Date, to timeZone: TimeZone) -> Date {
            // Interpret the given UTC date as absolute and produce a date that shows the same clock components in the provided time zone.
            // We do this by extracting components in the target time zone and rebuilding a Date from those components.
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = timeZone
            let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
            return calendar.date(from: comps) ?? date
        }

        // Determine the initial editing zone preference: event -> current
        // Note: Avoid referencing @State or other instance properties before initialization.
        let initialTZ: TimeZone = {
            if let evt = event, let tzId = evt.timezone, let tz = TimeZone(identifier: tzId) {
                return tz
            }
            // Fallback to a stable instance default to avoid shifts when device is in UTC
            if let tz = TimeZone(identifier: "America/New_York") { // TODO: Replace with your instance default if different
                return tz
            }
            return .current
        }()
        self.editingTimeZone = initialTZ

        // Round to minute helper
        func roundedToMinute(_ date: Date, in timeZone: TimeZone) -> Date {
            var cal = Calendar(identifier: .gregorian)
            cal.timeZone = timeZone
            let comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: date)
            return cal.date(from: comps) ?? date
        }

        if let evt = event {
            let local = convertUTCDate(evt.startAt, to: initialTZ)
            _startAtLocal = State(initialValue: roundedToMinute(local, in: initialTZ))
        } else {
            _startAtLocal = State(initialValue: roundedToMinute(Date(), in: initialTZ))
        }
        if let evt = event {
            let localEnd = convertUTCDate(evt.endAt, to: initialTZ)
            _endAtLocal = State(initialValue: roundedToMinute(localEnd, in: initialTZ))
        } else {
            let defaultEnd = Date().addingTimeInterval(3600)
            _endAtLocal = State(initialValue: roundedToMinute(defaultEnd, in: initialTZ))
        }
        _name = State(initialValue: event?.name ?? "")
        _description = State(initialValue: event?.description ?? "")
        _venueId = State(initialValue: event?.venueId ?? "")
        _venueName = State(initialValue: nil)
        _talentSelections = State(initialValue: [])
        _roomId = State(initialValue: event?.roomId ?? "")
        _capacity = State(initialValue: event?.capacity.map { String($0) } ?? "")
        _durationHours = State(initialValue: Self.durationHoursString(from: event?.durationMinutes))
        _isOnline = State(initialValue: event?.onlineURL != nil)
        _isInPerson = State(initialValue: event?.venueId.isEmpty == false || event == nil)
        _onlineURL = State(initialValue: event?.onlineURL?.absoluteString ?? "")
        _selectedCategory = State(initialValue: event?.category ?? "")
        _selectedGroupSlug = State(initialValue: event?.groupSlug ?? "")
        _imageURLs = State(initialValue: event?.images ?? [])
        _ticketDrafts = State(initialValue: event?.ticketTypes.map { TicketDraft(from: $0) } ?? [])
        _isRecurring = State(initialValue: event?.isRecurring ?? false)
        _attendeesVisible = State(initialValue: event?.attendeesVisible ?? true)

        // Capture initial wall-time components for the original event in the initial editing timezone
        if let evt = event {
            let comps = wallTimeComponents(from: roundedToMinute(convertUTCDate(evt.startAt, to: initialTZ), in: initialTZ), in: initialTZ)
            self.initialStartComponents = comps
        }
    }

    private static func durationHoursString(from minutes: Int?) -> String {
        guard let minutes else { return "" }
        let hours = Double(minutes) / 60.0
        if hours.truncatingRemainder(dividingBy: 1) == 0 {
            return String(Int(hours))
        }
        var formatted = String(format: "%.2f", hours)
        while formatted.contains("."), formatted.last == "0" {
            formatted.removeLast()
        }
        if formatted.last == "." {
            formatted.removeLast()
        }
        return formatted
    }

    private var trimmedOnlineURL: String {
        onlineURL.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var onlineURLMissing: Bool {
        isOnline && trimmedOnlineURL.isEmpty
    }

    private var onlineURLInvalid: Bool {
        isOnline && !trimmedOnlineURL.isEmpty && URL(string: trimmedOnlineURL) == nil
    }

    private var requiresVenueSelection: Bool {
        isInPerson && venueId.isEmpty
    }

    // Break complex disabled logic into smaller pieces to help the type-checker
    private var nameMissing: Bool {
        name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var eventTypeInvalid: Bool {
        !isInPerson && !isOnline
    }

    private var venueInvalid: Bool {
        requiresVenueSelection
    }

    private var onlineInvalid: Bool {
        onlineURLMissing || onlineURLInvalid
    }

    private var saveDisabled: Bool {
        if isSaving { return true }
        if nameMissing { return true }
        if eventTypeInvalid { return true }
        if venueInvalid { return true }
        if onlineInvalid { return true }
        return false
    }

    @ViewBuilder
    private var detailsSection: some View {
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
            DatePicker("Start", selection: $startAtLocal, displayedComponents: [.date, .hourAndMinute])
                .onChange(of: startAtLocal) { _, newValue in
                    let rounded = roundedToMinute(newValue, in: editingTimeZone)
                    if rounded != startAtLocal { startAtLocal = rounded }
                    if originalEvent == nil {
                        startWasModified = true
                    } else if let comps = initialStartComponents {
                        let nowComps = wallTimeComponents(from: rounded, in: editingTimeZone)
                        let changed = (comps.year != nowComps.year) ||
                                      (comps.month != nowComps.month) ||
                                      (comps.day != nowComps.day) ||
                                      (comps.hour != nowComps.hour) ||
                                      (comps.minute != nowComps.minute)
                        if changed { startWasModified = true }
                    }
                }
            Text("Editing TZ: \(editingTimeZone.identifier)")
                .font(.footnote)
                .foregroundColor(.secondary)
            Text("Picker wall: \(apiWallTimeStringWithSeconds(startAtLocal, in: editingTimeZone))")
                .font(.footnote)
                .foregroundColor(.secondary)
            TextField("Duration (hours)", text: $durationHours)
                .keyboardType(.decimalPad)
                .onChange(of: durationHours) { _, newValue in
                    let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                    if trimmed != initialDurationHours {
                        durationWasModified = true
                    }
                }
            TextField("Description", text: $description, axis: .vertical)
                .lineLimit(3...5)
        }
    }

    @ViewBuilder
    private var typeSection: some View {
        Section(header: Text("Type")) {
            Toggle("In-person", isOn: $isInPerson)
            Toggle("Online", isOn: $isOnline)
            if isOnline {
                TextField("Online URL", text: $onlineURL)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                if onlineURLMissing {
                    Text("Online events require a URL.")
                        .font(.footnote)
                        .foregroundColor(.red)
                }
                if !onlineURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, URL(string: onlineURL) == nil {
                    Text("Enter a valid URL for online events.")
                        .font(.footnote)
                        .foregroundColor(.red)
                }
            }
            if !isInPerson && !isOnline {
                Text("At least one type must be selected.")
                    .font(.footnote)
                    .foregroundColor(.red)
            }
        }
    }

    @ViewBuilder
    private var locationSection: some View {
        Section(header: Text("Location")) {
            if isLoadingVenues {
                ProgressView("Loading venues…")
            }
            if !availableVenues.isEmpty {
                Picker("Venue", selection: $venueId) {
                    ForEach(availableVenues) { venue in
                        Text(venue.name).tag(venue.id)
                    }
                }
                .onChange(of: venueId) { _, _ in
                    venueTimeZoneIdentifier = nil
                }
            } else {
                Text("No venues available. Add a venue in the web app, then refresh.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
            TextField("Room ID", text: $roomId)

            if let venueErrorMessage {
                Text(venueErrorMessage)
                    .font(.footnote)
                    .foregroundColor(.red)
            }
        }
    }

    @ViewBuilder
    private var organizationSection: some View {
        Section(header: Text("Organization")) {
            if !availableGroups.isEmpty {
                Picker("Pick list", selection: $selectedGroupSlug) {
                    Text("None").tag("")
                    ForEach(availableGroups) { group in
                        Text(group.name).tag(group.slug)
                    }
                }
            }

            if !availableCategories.isEmpty {
                Picker("Category", selection: $selectedCategory) {
                    Text("Uncategorized").tag("")
                    ForEach(availableCategories, id: \.self) { category in
                        Text(category).tag(category)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var participantsSection: some View {
        Section(header: Text("Participants")) {
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
        }
    }

    @ViewBuilder
    private var curatorsSection: some View {
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
    }

    @ViewBuilder
    private var fliersSection: some View {
        Section(header: Text("Fliers")) {
            if imageURLs.isEmpty {
                Text("Attach image files to use as fliers.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
            ForEach(Array(imageURLs.enumerated()), id: \.offset) { index, url in
                HStack {
                    Label(url.lastPathComponent, systemImage: "photo")
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                    Button(role: .destructive) {
                        imageURLs.remove(at: index)
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.borderless)
                }
            }
            PhotosPicker(selection: $flierSelection, matching: .images) {
                Label("Add flier", systemImage: "plus")
            }
        }
    }

    @ViewBuilder
    private var ticketsSection: some View {
        Section(header: Text("Tickets")) {
            if ticketDrafts.isEmpty {
                Text("Define ticket types, prices, and currency.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }

            ForEach(ticketDrafts) { draft in
                VStack(alignment: .leading) {
                    TextField("Ticket name", text: binding(for: draft).name)
                    HStack {
                        TextField("Price", text: binding(for: draft).price)
                            .keyboardType(.decimalPad)
                        TextField("Currency (e.g., USD)", text: binding(for: draft).currency)
                            .textInputAutocapitalization(.never)
                    }
                    Button(role: .destructive) {
                        removeTicket(draft)
                    } label: {
                        Label("Remove", systemImage: "trash")
                    }
                    .buttonStyle(.borderless)
                }
            }

            Button(action: { ticketDrafts.append(TicketDraft()) }) {
                Label("Add ticket", systemImage: "plus")
            }
        }
    }

    @ViewBuilder
    private var attendanceSection: some View {
        Section(header: Text("Attendance")) {
            Toggle("Attendee list visible", isOn: $attendeesVisible)
            Toggle("Recurring event", isOn: $isRecurring)
            TextField("Capacity", text: $capacity)
                .keyboardType(.numberPad)
        }
    }

    var body: some View {
        Form {
            detailsSection
            typeSection
            locationSection
            organizationSection
            participantsSection
            curatorsSection
            fliersSection
            ticketsSection
            attendanceSection

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
                .disabled(saveDisabled)
            }
        }
        .onChange(of: flierSelection) { _, newItems in
            Task { await importFliers(from: newItems) }
        }
        .task { await loadResources() }
        .environment(\.timeZone, editingTimeZone)
        .task {
            await loadResources()
            if let evt = originalEvent {
                let serverTZ: TimeZone = {
                    if let tzId = evt.rawTimezoneIdentifier ?? evt.timezone, let tz = TimeZone(identifier: tzId) { return tz }
                    return editingTimeZone
                }()

                if let raw = evt.rawStartsAtString {
                    let f = DateFormatter()
                    f.calendar = Calendar(identifier: .gregorian)
                    f.timeZone = serverTZ
                    f.locale = Locale(identifier: "en_US_POSIX")
                    f.dateFormat = "yyyy-MM-dd HH:mm:ss"
                    if let serverWallDate = f.date(from: raw) {
                        let serverWallRounded = roundedToMinute(serverWallDate, in: serverTZ)
                        let serverWallString = apiWallTimeStringWithSeconds(serverWallRounded, in: serverTZ)

                        let pickerInServerTZRounded = roundedToMinute(startAtLocal, in: serverTZ)
                        let pickerWallStringInServerTZ = apiWallTimeStringWithSeconds(pickerInServerTZRounded, in: serverTZ)

                        if pickerWallStringInServerTZ != serverWallString {
                            startWasModified = true
                            let serverWallComponents = wallTimeComponents(from: serverWallRounded, in: serverTZ)
                            if let normalizedInEditingTZ = date(from: serverWallComponents, in: editingTimeZone) {
                                startAtLocal = roundedToMinute(normalizedInEditingTZ, in: editingTimeZone)
                            }
                        }
                    }
                } else {
                    let serverWallRounded = roundedToMinute(evt.startAt, in: serverTZ)
                    let serverWallString = apiWallTimeStringWithSeconds(serverWallRounded, in: serverTZ)

                    let pickerInServerTZRounded = roundedToMinute(startAtLocal, in: serverTZ)
                    let pickerWallStringInServerTZ = apiWallTimeStringWithSeconds(pickerInServerTZRounded, in: serverTZ)

                    if pickerWallStringInServerTZ != serverWallString {
                        startWasModified = true
                        let serverWallComponents = wallTimeComponents(from: serverWallRounded, in: serverTZ)
                        if let normalizedInEditingTZ = date(from: serverWallComponents, in: editingTimeZone) {
                            startAtLocal = roundedToMinute(normalizedInEditingTZ, in: editingTimeZone)
                        }
                    }
                }
            }
        }
        .accentColor(theme.accent)
    }

    private func apiDateString(_ date: Date) -> String {
        let formatter = Event.payloadDateFormatter(timeZone: editingTimeZone)
        return formatter.string(from: date)
    }
    
    private func apiWallTimeString(_ date: Date, in timeZone: TimeZone) -> String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.timeZone = timeZone
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd'T'HH:mm"
        return f.string(from: date)
    }

    private func apiWallTimeStringWithSeconds(_ date: Date, in timeZone: TimeZone) -> String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.timeZone = timeZone
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd HH:mm:ss" // Backend-required format (Y-m-d H:i:s)
        return f.string(from: date)
    }

    private func apiUTCStringWithSeconds(_ date: Date) -> String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return f.string(from: date)
    }

    private func wallTimeComponents(from date: Date, in timeZone: TimeZone) -> DateComponents {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        return cal.dateComponents([.year, .month, .day, .hour, .minute], from: date)
    }

    private func date(from components: DateComponents, in timeZone: TimeZone) -> Date? {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        return cal.date(from: components)
    }
    
    private func roundedToMinute(_ date: Date, in timeZone: TimeZone) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        let comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        return cal.date(from: comps) ?? date
    }
    
    private func isSignificantlyDifferent(_ a: Date, _ b: Date, toleranceSeconds: TimeInterval = 1) -> Bool {
        return abs(a.timeIntervalSince1970 - b.timeIntervalSince1970) > toleranceSeconds
    }

    private struct EventPatchDTO: Encodable {
        var name: String?
        var description: String?
        var starts_at: String?
        var ends_at: String?
        var duration: Int??
        var room_id: String??
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
        var category: String??
        var group_slug: String??
        var online_url: String??
        var images: [URL]?
        var ticket_types: [TicketType]?
        var timezone: String??
        var attendees_visible: Bool??
        var is_recurring: Bool??

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


        let parsedDurationMinutes: Int?
        if let durationValue = Double(durationHours.trimmingCharacters(in: .whitespacesAndNewlines)), durationValue > 0 {
            parsedDurationMinutes = Int(durationValue * 60)
        } else {
            parsedDurationMinutes = nil
        }

        if originalEvent == nil {
            // Use a rounded start to avoid seconds variance
            let roundedStartCreate = roundedToMinute(startAtLocal, in: editingTimeZone)
            let computedEndAt: Date
            if let parsedDurationMinutes, parsedDurationMinutes > 0 {
                computedEndAt = roundedStartCreate.addingTimeInterval(TimeInterval(parsedDurationMinutes * 60))
            } else {
                computedEndAt = endAtLocal
            }

            let cleanedImages: [URL] = imageURLs
                .map { $0.absoluteString }
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .compactMap { URL(string: $0) }

            let ticketTypes: [TicketType] = ticketDrafts.compactMap { $0.toTicketType() }

            let onlineLink = parsedOnlineURL()

            Task {
                do {
                    print("[DEBUG] Create: editingTZ=", editingTimeZone.identifier)
                    print("[DEBUG] Create: startAtLocal=", apiWallTimeStringWithSeconds(roundedStartCreate, in: editingTimeZone))
                    print("[DEBUG] Create: computedEndAt=", apiDateString(computedEndAt))

                    let validTalentIds: [String] = availableTalent
                        .map { $0.id }
                        .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                        .filter { talentSelections.contains($0) }

                    let payload = Event(
                        id: UUID().uuidString,
                        name: name,
                        description: description.isEmpty ? nil : description,
                        startAt: roundedStartCreate,
                        endAt: computedEndAt,
                        durationMinutes: parsedDurationMinutes,
                        venueId: isInPerson ? venueId : "",
                        roomId: roomId.isEmpty ? nil : roomId,
                        images: cleanedImages,
                        capacity: Int(capacity),
                        ticketTypes: ticketTypes,
                        curatorId: curatorSelections.first,
                        talentIds: validTalentIds,
                        category: selectedCategory.isEmpty ? nil : selectedCategory,
                        groupSlug: selectedGroupSlug.isEmpty ? nil : selectedGroupSlug,
                        onlineURL: onlineLink,
                        isRecurring: isRecurring,
                        attendeesVisible: attendeesVisible
                    )

                    let savedEvent = try await repository.createEvent(
                        payload,
                        instance: instance,
                        timeZoneOverride: editingTimeZone
                    )

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
        } else {
            // Reconstruct the absolute start date from current wall-time components in the editing timezone
            let currentStartComponents = wallTimeComponents(from: startAtLocal, in: editingTimeZone)
            let reconstructedStartRaw = date(from: currentStartComponents, in: editingTimeZone) ?? startAtLocal
            let reconstructedStart = roundedToMinute(reconstructedStartRaw, in: editingTimeZone)

            let computedEndAt: Date
            if let parsedDurationMinutes, parsedDurationMinutes > 0 {
                computedEndAt = reconstructedStart.addingTimeInterval(TimeInterval(parsedDurationMinutes * 60))
            } else {
                computedEndAt = endAtLocal
            }

            Task {
                do {
                    print("[DEBUG] Edit: editingTZ=", editingTimeZone.identifier)
                    // Send local wall time strings in the supplied timezone per server contract
                    print("[DEBUG] Edit: reconstructedStart(WALL)=", apiWallTimeStringWithSeconds(reconstructedStart, in: editingTimeZone))
                    print("[DEBUG] Edit: reconstructedStart(UTC)=", apiUTCStringWithSeconds(reconstructedStart))

                    var dto = EventPatchDTO()
                    // Always send time fields on edit
//                    dto.starts_at = apiUTCStringWithSeconds(reconstructedStart)
//                    dto.ends_at = apiUTCStringWithSeconds(computedEndAt)
//                    dto.timezone = .some(editingTimeZone.identifier)
                    // Send local wall time strings in the supplied timezone per server contract
                    dto.starts_at = apiWallTimeStringWithSeconds(reconstructedStart, in: editingTimeZone)
                    dto.ends_at = apiWallTimeStringWithSeconds(computedEndAt, in: editingTimeZone)
                    dto.timezone = .some(editingTimeZone.identifier)

                    let parsedDurationValue = parsedDurationMinutes
                    if let parsedDurationValue, parsedDurationValue != originalEvent!.durationMinutes {
                        dto.duration = .some(parsedDurationValue / 60)
                    } else if parsedDurationValue == nil, originalEvent!.durationMinutes != nil {
                        dto.duration = .some(nil)
                    }
                    let trimmedRoom = roomId.trimmingCharacters(in: .whitespacesAndNewlines)
                    let originalRoomTrimmed = originalEvent!.roomId?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    if trimmedRoom != originalRoomTrimmed {
                        dto.room_id = trimmedRoom.isEmpty ? .some(nil) : .some(trimmedRoom)
                    }
                    let originalCapacityStr = originalEvent!.capacity.map { String($0) } ?? ""
                    if capacity != originalCapacityStr {
                        if let capInt = Int(capacity) { dto.capacity = .some(capInt) } else { dto.capacity = .some(nil) }
                    }
                    if selectedCategory != (originalEvent!.category ?? "") {
                        dto.category = selectedCategory.isEmpty ? .some(nil) : .some(selectedCategory)
                    }
                    if selectedGroupSlug != (originalEvent!.groupSlug ?? "") {
                        dto.group_slug = selectedGroupSlug.isEmpty ? .some(nil) : .some(selectedGroupSlug)
                    }
                    let currentOnlineString = parsedOnlineURL()?.absoluteString ?? ""
                    let originalOnline = originalEvent!.onlineURL?.absoluteString ?? ""
                    if currentOnlineString != originalOnline {
                        if let link = parsedOnlineURL() {
                            dto.online_url = .some(link.absoluteString)
                        } else if trimmedOnlineURL.isEmpty {
                            dto.online_url = .some(nil)
                        }
                    }
                    let cleanedImages: [URL] = imageURLs
                        .map { $0.absoluteString }
                        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                        .compactMap { URL(string: $0) }
                    if cleanedImages != originalEvent!.images {
                        dto.images = cleanedImages
                    }
                    let ticketTypes: [TicketType] = ticketDrafts.compactMap { $0.toTicketType() }
                    dto.ticket_types = ticketTypes
                    if venueId != originalEvent!.venueId && !venueId.isEmpty { dto.venue_id = venueId }
                    if participantsModified {
                        var members: [EventPatchDTO.MemberPatch] = []
                        let validTalentIds: [String] = availableTalent
                            .map { $0.id }
                            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                            .filter { talentSelections.contains($0) }
                        members.append(contentsOf: validTalentIds.map { .init(id: $0, name: nil, email: nil, youtube_url: nil) })
                        if !members.isEmpty { dto.members = members }
                    }
                    if curatorsModified {
                        let selectedCuratorIds = availableCurators
                            .map { $0.id }
                            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                            .filter { curatorSelections.contains($0) }
                        dto.curators = selectedCuratorIds.map { EventPatchDTO.CuratorPatch(id: $0) }
                    }
                    if attendeesVisible != (originalEvent!.attendeesVisible ?? true) {
                        dto.attendees_visible = .some(attendeesVisible)
                    }
                    if isRecurring != (originalEvent!.isRecurring ?? false) {
                        dto.is_recurring = .some(isRecurring)
                    }

                    let savedEvent = try await repository.patchEvent(id: originalEvent!.id, body: dto, instance: instance)

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
                availableCategories = resources.categories
                availableGroups = resources.groups

                if talentSelections.isEmpty, let existingTalent = originalEvent?.talentIds {
                    talentSelections = Set(existingTalent)
                }

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

    private func parsedOnlineURL() -> URL? {
        guard isOnline else { return nil }
        let trimmed = trimmedOnlineURL
        guard !trimmed.isEmpty else { return nil }
        return URL(string: trimmed)
    }

    private func importFliers(from items: [PhotosPickerItem]) async {
        guard !items.isEmpty else { return }
        for item in items {
            guard let data = try? await item.loadTransferable(type: Data.self), !data.isEmpty else { continue }
            let destination = FileManager.default.temporaryDirectory.appendingPathComponent("flier-\(UUID().uuidString).jpg")
            do {
                try data.write(to: destination)
                await MainActor.run {
                    if !imageURLs.contains(destination) {
                        imageURLs.append(destination)
                    }
                }
            } catch {
                continue
            }
        }
        await MainActor.run { flierSelection = [] }
    }

    private func binding(for draft: TicketDraft) -> TicketDraft.BindingProxy {
        guard let index = ticketDrafts.firstIndex(where: { $0.id == draft.id }) else {
            return TicketDraft.BindingProxy(
                name: .constant(draft.name),
                price: .constant(draft.price),
                currency: .constant(draft.currency)
            )
        }

        return TicketDraft.BindingProxy(
            name: Binding(
                get: { ticketDrafts[index].name },
                set: { ticketDrafts[index].name = $0 }
            ),
            price: Binding(
                get: { ticketDrafts[index].price },
                set: { ticketDrafts[index].price = $0 }
            ),
            currency: Binding(
                get: { ticketDrafts[index].currency },
                set: { ticketDrafts[index].currency = $0 }
            )
        )
    }

    private func removeTicket(_ draft: TicketDraft) {
        ticketDrafts.removeAll { $0.id == draft.id }
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

}

private struct TicketDraft: Identifiable, Equatable {
    let id: UUID
    var name: String
    var price: String
    var currency: String

    init(id: UUID = UUID(), name: String = "", price: String = "", currency: String = "") {
        self.id = id
        self.name = name
        self.price = price
        self.currency = currency
    }

    init(from ticket: TicketType) {
        self.id = UUID()
        self.name = ticket.name
        if let price = ticket.price {
            self.price = NSDecimalNumber(decimal: price).stringValue
        } else {
            self.price = ""
        }
        self.currency = ticket.currency ?? ""
    }

    func toTicketType() -> TicketType? {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return nil }
        let trimmedPrice = price.trimmingCharacters(in: .whitespacesAndNewlines)
        let decimalPrice = Decimal(string: trimmedPrice)
        let trimmedCurrency = currency.trimmingCharacters(in: .whitespacesAndNewlines)
        return TicketType(
            id: id.uuidString,
            name: trimmedName,
            price: decimalPrice,
            currency: trimmedCurrency.isEmpty ? nil : trimmedCurrency
        )
    }

    struct BindingProxy {
        let name: Binding<String>
        let price: Binding<String>
        let currency: Binding<String>
    }
}
