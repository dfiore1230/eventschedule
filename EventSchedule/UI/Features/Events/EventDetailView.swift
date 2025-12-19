import SwiftUI

struct EventDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appSettings: AppSettings

    @State private var event: Event
    @State private var isEditing: Bool = false
    @State private var isPerformingAction: Bool = false
    @State private var actionError: String?
    @State private var showingDeleteConfirm: Bool = false
    @State private var showingScanner: Bool = false
    @State private var isProcessingScan: Bool = false
    @State private var scanResult: ScanResult?
    @State private var scanToastMessage: String?
    @State private var showingScanToast: Bool = false

    private let repository: EventRepository
    private let checkInRepository: CheckInRepositoryProtocol
    private let instance: InstanceProfile
    private let onSave: ((Event) -> Void)?
    private let onDelete: ((Event) -> Void)?

    init(
        event: Event,
        repository: EventRepository,
        checkInRepository: CheckInRepositoryProtocol,
        instance: InstanceProfile,
        onSave: ((Event) -> Void)? = nil,
        onDelete: ((Event) -> Void)? = nil
    ) {
        self.repository = repository
        self.checkInRepository = checkInRepository
        self.instance = instance
        self.onSave = onSave
        self.onDelete = onDelete
        _event = State(initialValue: event)
    }
    
    private func makeAbsoluteURL(_ urlString: String?) -> URL? {
        guard let urlString = urlString, !urlString.isEmpty else { return nil }
        
        // If already absolute, return as-is
        if urlString.hasPrefix("http://") || urlString.hasPrefix("https://") {
            return URL(string: urlString)
        }
        
        // Convert relative URL to absolute
        var baseURLString = instance.baseURL.absoluteString
        if baseURLString.hasSuffix("/api") {
            baseURLString = String(baseURLString.dropLast(4))
        }
        if baseURLString.hasSuffix("/") {
            baseURLString = String(baseURLString.dropLast())
        }
        let path = urlString.hasPrefix("/") ? urlString : "/" + urlString
        return URL(string: baseURLString + path)
    }

    private func normalizeEventIdFromQR(_ raw: String) -> String? {
        if let intVal = Int(raw) { return String(intVal) }
        if let data = Data(base64Encoded: raw),
           let decoded = String(data: data, encoding: .utf8),
           let intVal = Int(decoded) {
            return String(intVal)
        }
        return nil
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

            if event.isRecurring == true {
                Section(header: Text("Recurrence")) {
                    Label("Repeats", systemImage: "arrow.triangle.2.circlepath")
                        .foregroundColor(.secondary)
                }
            }

            Section(header: Text("Attendance")) {
                if let capacity = event.capacity {
                    HStack {
                        Label("Capacity", systemImage: "person.3")
                        Spacer()
                        Text(String(capacity))
                            .foregroundColor(.secondary)
                    }
                }
                Label(
                    (event.attendeesVisible ?? true) ? "Attendee list visible" : "Attendee list hidden",
                    systemImage: (event.attendeesVisible ?? true) ? "eye" : "eye.slash"
                )
                .foregroundColor(.secondary)
            }
            
            if let url = makeAbsoluteURL(event.flyerImageUrl) {
                Section(header: Text("Event Flyer")) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    } placeholder: {
                        ProgressView()
                    }
                    .frame(maxHeight: 300)
                    .cornerRadius(8)
                }
            }

            if !event.ticketTypes.isEmpty {
                Section(header: Text("Tickets")) {
                    Button {
                        showingScanner = true
                    } label: {
                        Label("Scan Ticket", systemImage: "qrcode.viewfinder")
                    }
                    .disabled(isProcessingScan)
                    
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
            ToolbarItem(placement: .navigationBarTrailing) {
                if let shareURL = event.onlineURL {
                    ShareLink(item: shareURL, subject: Text(event.name), message: Text(event.description ?? "")) {
                        Image(systemName: "square.and.arrow.up")
                    }
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
        .sheet(isPresented: $showingScanner) {
            QRScannerView { scannedCode in
                showingScanner = false
                Task {
                    await processScan(code: scannedCode)
                }
            }
        }
        .overlay(alignment: .bottom) {
            if showingScanToast, let message = scanToastMessage {
                Text(message)
                    .font(.body)
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(10)
                    .padding()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .accessibilityIdentifier("ScanToast")
                    .onTapGesture {
                        withAnimation { showingScanToast = false }
                        isProcessingScan = false
                    }
            }
        }
        .task { await refreshEventDetails() }
        .tint(.accentColor)
        // Debug overlay removed
    }
    
    private func processScan(code: String) async {
        guard !isProcessingScan else { return }
        isProcessingScan = true

        // Parse QR locally to aid debugging
        // Can be either plain code or legacy URL format
        var extractedCode = code.trimmingCharacters(in: .whitespacesAndNewlines)
        var extractedEventId: String? = nil
        
        if let url = URL(string: code) {
            let parts = url.pathComponents.filter { $0 != "/" }
            if parts.count >= 4 && parts[0] == "ticket" && parts[1] == "view" {
                // Legacy URL format
                var urlCode = parts[3]
                if let decoded = urlCode.removingPercentEncoding { urlCode = decoded }
                extractedCode = urlCode
                extractedEventId = normalizeEventIdFromQR(parts[2]) ?? parts[2]
            }
        }
        
        // Log debug info to console only
        print("[Scan Debug] code: \(extractedCode), event_id: \(String(describing: extractedEventId))")
        
        do {
            let result = try await checkInRepository.scanTicket(
                code: code,
                eventId: event.id,
                gateId: nil,
                deviceId: UIDevice.current.identifierForVendor?.uuidString,
                instance: instance
            )
            await MainActor.run {
                scanResult = result
                if result.status.isSuccess {
                    let holderInfo = result.holder ?? "Unknown"
                    scanToastMessage = "✅ \(result.status.displayName) - \(holderInfo)"
                } else {
                    scanToastMessage = "⚠️ \(result.status.displayName)"
                    if let message = result.message {
                        scanToastMessage! += ": \(message)"
                    }
                }
                showingScanToast = true
                isProcessingScan = false
                Task {
                    try? await Task.sleep(nanoseconds: 3_000_000_000)
                    withAnimation { showingScanToast = false }
                }
            }
        } catch let decodingError as DecodingError {
            // Swift-level decoding errors (rare)
            await MainActor.run {
                scanResult = nil
                scanToastMessage = "❌ Scan failed: Invalid server response. Please update the app or contact support."
                showingScanToast = true
                isProcessingScan = false
                Task {
                    try? await Task.sleep(nanoseconds: 6_000_000_000)
                    withAnimation { showingScanToast = false }
                }
            }
        } catch let apiError as APIError {
            // APIError.decodingError may include a body preview in its localizedDescription.
            // Avoid showing that raw body to users; present a generic, user-friendly message instead.
            await MainActor.run {
                scanResult = nil
                switch apiError {
                case .decodingError:
                    scanToastMessage = "❌ Scan failed: Invalid server response. Please update the app or contact support."
                default:
                    let errMsg = apiError.errorDescription ?? "An error occurred"
                    scanToastMessage = "❌ Scan failed: \(errMsg)"
                }
                showingScanToast = true
                isProcessingScan = false
                Task {
                    try? await Task.sleep(nanoseconds: 6_000_000_000)
                    withAnimation { showingScanToast = false }
                }
            }
        } catch {
            await MainActor.run {
                scanResult = nil
                scanToastMessage = "❌ Scan failed: \(error.localizedDescription)"
                showingScanToast = true
                isProcessingScan = false
                Task {
                    try? await Task.sleep(nanoseconds: 3_000_000_000)
                    withAnimation { showingScanToast = false }
                }
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

    private func refreshEventDetails() async {
        do {
            let latest = try await repository.getEvent(id: event.id, instance: instance)
            await MainActor.run {
                event = latest
            }
        } catch {
            // Keep showing the existing event; avoid surfacing error inline
        }
    }
}
