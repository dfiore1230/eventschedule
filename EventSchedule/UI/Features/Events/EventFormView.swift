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
    @State private var guestListVisibility: String = "attendees_only"
    @State private var ticketsEnabled: Bool = false
    @State private var ticketCurrencyCode: String = ""
    @State private var totalTicketsMode: String = "individual"
    @State private var ticketNotes: String = ""
    @State private var paymentMethod: String = "online"
    @State private var paymentInstructions: String = ""
    @State private var expireUnpaidTickets: Bool = false
    @State private var remindUnpaidTicketsEvery: String = ""
    @State private var registrationURL: String = ""
    @State private var eventPassword: String = ""
    @State private var flyerImageId: String = ""
    @State private var scheduleSlug: String = ""

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

    private var saveDisabled: Bool {
        let trimmedNameEmpty = name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let typeInvalid = (!isInPerson && !isOnline)
        let venueMissing = requiresVenueSelection
        let linkMissing = onlineURLMissing
        let linkInvalid = onlineURLInvalid
        let currentlySaving = isSaving
        return currentlySaving || trimmedNameEmpty || typeInvalid || venueMissing || linkMissing || linkInvalid
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
                DatePicker("Start", selection: $startAtLocal, displayedComponents: [.date, .hourAndMinute])
                    .onChange(of: startAtLocal) { _, newValue in
                        let rounded = roundedToMinute(newValue, in: editingTimeZone)
                        if rounded != startAtLocal { startAtLocal = rounded }
                        if originalEvent == nil {
                            startWasModified = true
                        } else if let comps = initialStartComponents {
                            let nowComps = wallTimeComponents(from: rounded, in: editingTimeZone)
                            // Compare year, month, day, hour, minute
                            let changed = (comps.year != nowComps.year) ||
                                          (comps.month != nowComps.month) ||
                                          (comps.day != nowComps.day) ||
                                          (comps.hour != nowComps.hour) ||
                                          (comps.minute != nowComps.minute)
                            if changed { startWasModified = true }
                        }
                    }
                // DEBUG: Effective timezone and picker wall time
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
                        TextField("Quantity available", text: binding(for: draft).quantity)
                            .keyboardType(.numberPad)
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
            
            Section(header: Text("Ticketing Options")) {
                Toggle("Enable tickets", isOn: $ticketsEnabled)
                Picker("Quantity mode", selection: $totalTicketsMode) {
                    Text("Individual").tag("individual")
                    Text("Combined").tag("combined")
                }
                TextField("Ticket currency code (e.g., USD)", text: $ticketCurrencyCode)
                    .textInputAutocapitalization(.never)
                TextField("Ticket notes", text: $ticketNotes, axis: .vertical)
                    .lineLimit(2...4)
                Picker("Payment method", selection: $paymentMethod) {
                    Text("Online").tag("online")
                    Text("Cash (offline)").tag("cash")
                }
                if paymentMethod == "cash" {
                    TextField("Payment instructions", text: $paymentInstructions, axis: .vertical)
                        .lineLimit(2...4)
                }
                Toggle("Expire unpaid tickets", isOn: $expireUnpaidTickets)
                TextField("Remind unpaid every (hours)", text: $remindUnpaidTicketsEvery)
                    .keyboardType(.numberPad)
                TextField("Registration URL", text: $registrationURL)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
            }
            
            Section(header: Text("Security & Media")) {
                SecureField("Event password", text: $eventPassword)
                TextField("Flyer image ID", text: $flyerImageId)
                    .keyboardType(.numberPad)
            }

            Section(header: Text("Attendance")) {
                TextField("Capacity", text: $capacity)
                    .keyboardType(.numberPad)
                Toggle("Recurring event", isOn: $isRecurring)
            }
            
            Section(header: Text("Guest List")) {
                Toggle("Show guest list", isOn: $attendeesVisible)
                Picker("Visibility", selection: $guestListVisibility) {
                    Text("Attendees only").tag("attendees_only")
                    Text("Paid").tag("paid")
                    Text("Public").tag("public")
                }
            }
            
            Section(header: Text("Schedule")) {
                TextField("Sub-schedule slug (optional)", text: $scheduleSlug)
                    .textInputAutocapitalization(.never)
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
                .disabled(saveDisabled)
            }
        }
        .onChange(of: flierSelection) { _, newItems in
            Task { await importFliers(from: newItems) }
        }
        .task {
            await loadResources()
            // After loading, for existing events, verify that the picker's wall time matches the original event's server wall time.
            if let evt = originalEvent {
                // Prefer raw server fields when available to avoid interpretation drift
                let serverTZ: TimeZone = {
                    if let tzId = evt.rawTimezoneIdentifier ?? evt.timezone, let tz = TimeZone(identifier: tzId) { return tz }
                    return editingTimeZone
                }()

                if let raw = evt.rawStartsAtString {
                    // Parse raw server wall-time string in server TZ using strict format
                    let f = DateFormatter()
                    f.calendar = Calendar(identifier: .gregorian)
                    f.timeZone = serverTZ
                    f.locale = Locale(identifier: "en_US_POSIX")
                    f.dateFormat = "yyyy-MM-dd HH:mm:ss"
                    if let serverWallDate = f.date(from: raw) {
                        let serverWallRounded = roundedToMinute(serverWallDate, in: serverTZ)
                        let serverWallString = apiWallTimeStringWithSeconds(serverWallRounded, in: serverTZ)

                        // Picker wall time as interpreted in server TZ
                        let pickerInServerTZRounded = roundedToMinute(startAtLocal, in: serverTZ)
                        let pickerWallStringInServerTZ = apiWallTimeStringWithSeconds(pickerInServerTZRounded, in: serverTZ)

                        if pickerWallStringInServerTZ != serverWallString {
                            startWasModified = true
                            // Normalize the picker to reflect the server wall time but displayed in the editing timezone
                            let serverWallComponents = wallTimeComponents(from: serverWallRounded, in: serverTZ)
                            if let normalizedInEditingTZ = date(from: serverWallComponents, in: editingTimeZone) {
                                startAtLocal = roundedToMinute(normalizedInEditingTZ, in: editingTimeZone)
                            }
                        }
                    }
                } else {
                    // Fallback to previous comparison using evt.startAt in server TZ
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
        .environment(\.timeZone, editingTimeZone)
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

            let ticketTypes: [TicketType] = ticketDrafts.compactMap { $0.toTicketType() }

            let onlineLink = parsedOnlineURL()

            Task {
                do {
                    let validTalentIds: [String] = Array(Set(
                        availableTalent
                            .map { $0.id.trimmingCharacters(in: .whitespacesAndNewlines) }
                            .filter { !$0.isEmpty }
                            .filter { talentSelections.contains($0) }
                    ))

                    let selectedCuratorId: String? = {
                        let ids = availableCurators
                            .map { $0.id.trimmingCharacters(in: .whitespacesAndNewlines) }
                            .filter { !$0.isEmpty }
                            .filter { curatorSelections.contains($0) }
                        return ids.first
                    }()

                    let options = RemoteEventRepository.ExtendedEventOptions(
                        categoryName: selectedCategory.isEmpty ? nil : selectedCategory,
                        ticketsEnabled: ticketsEnabled ? true : nil,
                        ticketCurrencyCode: ticketCurrencyCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : ticketCurrencyCode.trimmingCharacters(in: .whitespacesAndNewlines),
                        totalTicketsMode: totalTicketsMode,
                        ticketNotes: ticketNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : ticketNotes,
                        paymentMethod: paymentMethod,
                        paymentInstructions: paymentMethod == "cash" ? (paymentInstructions.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : paymentInstructions) : nil,
                        expireUnpaidTickets: expireUnpaidTickets ? true : nil,
                        remindUnpaidTicketsEvery: Int(remindUnpaidTicketsEvery.trimmingCharacters(in: .whitespacesAndNewlines)),
                        registrationUrl: URL(string: registrationURL.trimmingCharacters(in: .whitespacesAndNewlines)),
                        eventPassword: eventPassword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : eventPassword,
                        flyerImageId: Int(flyerImageId.trimmingCharacters(in: .whitespacesAndNewlines)),
                        guestListVisibility: guestListVisibility,
                        members: buildMemberDTOs(),
                        schedule: scheduleSlug.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : scheduleSlug
                    )

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
                        curatorId: selectedCuratorId,
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
                        timeZoneOverride: editingTimeZone,
                        options: options
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
                    let validTalentIds: [String] = Array(Set(
                        availableTalent
                            .map { $0.id.trimmingCharacters(in: .whitespacesAndNewlines) }
                            .filter { !$0.isEmpty }
                            .filter { talentSelections.contains($0) }
                    ))
                    let selectedCuratorId: String? = {
                        let ids = availableCurators
                            .map { $0.id.trimmingCharacters(in: .whitespacesAndNewlines) }
                            .filter { !$0.isEmpty }
                            .filter { curatorSelections.contains($0) }
                        return ids.first
                    }()

                    let options = RemoteEventRepository.ExtendedEventOptions(
                        categoryName: selectedCategory.isEmpty ? nil : selectedCategory,
                        ticketsEnabled: ticketsEnabled ? true : nil,
                        ticketCurrencyCode: ticketCurrencyCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : ticketCurrencyCode.trimmingCharacters(in: .whitespacesAndNewlines),
                        totalTicketsMode: totalTicketsMode,
                        ticketNotes: ticketNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : ticketNotes,
                        paymentMethod: paymentMethod,
                        paymentInstructions: paymentMethod == "cash" ? (paymentInstructions.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : paymentInstructions) : nil,
                        expireUnpaidTickets: expireUnpaidTickets ? true : nil,
                        remindUnpaidTicketsEvery: Int(remindUnpaidTicketsEvery.trimmingCharacters(in: .whitespacesAndNewlines)),
                        registrationUrl: URL(string: registrationURL.trimmingCharacters(in: .whitespacesAndNewlines)),
                        eventPassword: eventPassword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : eventPassword,
                        flyerImageId: Int(flyerImageId.trimmingCharacters(in: .whitespacesAndNewlines)),
                        guestListVisibility: guestListVisibility,
                        members: buildMemberDTOs(),
                        schedule: scheduleSlug.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : scheduleSlug
                    )

                    let updatedEvent = Event(
                        id: originalEvent!.id,
                        name: name,
                        description: description.isEmpty ? nil : description,
                        startAt: reconstructedStart,
                        endAt: computedEndAt,
                        durationMinutes: parsedDurationMinutes,
                        venueId: isInPerson ? venueId : "",
                        venueName: originalEvent?.venueName,
                        roomId: roomId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : roomId,
                        images: imageURLs,
                        capacity: Int(capacity),
                        ticketTypes: ticketDrafts.compactMap { $0.toTicketType() },
                        publishState: originalEvent?.publishState ?? .draft,
                        curatorId: selectedCuratorId,
                        talentIds: validTalentIds,
                        category: selectedCategory.isEmpty ? nil : selectedCategory,
                        groupSlug: selectedGroupSlug.isEmpty ? nil : selectedGroupSlug,
                        onlineURL: parsedOnlineURL(),
                        timezone: editingTimeZone.identifier,
                        isRecurring: isRecurring,
                        attendeesVisible: attendeesVisible
                    )

                    let savedEvent = try await repository.updateEvent(
                        updatedEvent,
                        instance: instance,
                        timeZoneOverride: editingTimeZone,
                        options: options
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
                currency: .constant(draft.currency),
                quantity: .constant(draft.quantity)
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
            ),
            quantity: Binding(
                get: { ticketDrafts[index].quantity },
                set: { ticketDrafts[index].quantity = $0 }
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
    
    private func buildMemberDTOs() -> [RemoteEventRepository.MemberDTO] {
        let selected = availableTalent.filter { talentSelections.contains($0.id) }
        return selected.map { role in
            RemoteEventRepository.MemberDTO(
                name: role.name,
                email: nil,
                youtube_url: nil
            )
        }
    }

}

private struct TicketDraft: Identifiable, Equatable {
    let id: UUID
    var name: String
    var price: String
    var currency: String
    var quantity: String

    init(id: UUID = UUID(), name: String = "", price: String = "", currency: String = "", quantity: String = "") {
        self.id = id
        self.name = name
        self.price = price
        self.currency = currency
        self.quantity = quantity
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
        self.quantity = ticket.quantity.map(String.init) ?? ""
    }

    func toTicketType() -> TicketType? {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return nil }
        let trimmedPrice = price.trimmingCharacters(in: .whitespacesAndNewlines)
        let decimalPrice = Decimal(string: trimmedPrice)
        let trimmedCurrency = currency.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedQuantity = quantity.trimmingCharacters(in: .whitespacesAndNewlines)
        let parsedQuantity = Int(trimmedQuantity)
        return TicketType(
            id: id.uuidString,
            name: trimmedName,
            price: decimalPrice,
            currency: trimmedCurrency.isEmpty ? nil : trimmedCurrency,
            quantity: parsedQuantity
        )
    }

    struct BindingProxy {
        let name: Binding<String>
        let price: Binding<String>
        let currency: Binding<String>
        let quantity: Binding<String>
    }
}

