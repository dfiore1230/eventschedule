import SwiftUI

struct InstanceOnboardingPlaceholder: View {
    @EnvironmentObject var instanceStore: InstanceStore
    @Environment(\.theme) private var theme
    @Environment(\.httpClient) private var httpClient

    @State private var urlString: String = ""
    @State private var apiKey: String = ""
    @State private var isConnecting: Bool = false
    @State private var errorMessage: String?
    @State private var showingError: Bool = false
    @FocusState private var urlFieldFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Text("Add an Planify Instance")
                        .font(.title2)
                        .bold()

                    TextField("https://events.example.com", text: $urlString)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(8)
                        .focused($urlFieldFocused)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Enter API Key")
                            .font(.headline)

                        SecureField("API Key", text: $apiKey)
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(8)
                    }

                    Button(action: addInstance) {
                        Text("Connect")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(theme.primary)
                            .foregroundColor(theme.background)
                            .cornerRadius(theme.buttonRadius)
                            .overlay {
                                if isConnecting {
                                    ProgressView()
                                        .progressViewStyle(.circular)
                                        .tint(theme.background)
                                }
                            }
                    }
                    .disabled(urlString.isEmpty || apiKey.isEmpty || isConnecting)

                    Spacer()
                }
                .padding()
            }
            .scrollDismissesKeyboard(.immediately)
            .ignoresSafeArea(.keyboard, edges: .bottom)
            .navigationTitle("Planify")
        }
        .alert("Connection Failed", isPresented: $showingError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage ?? "Unknown error")
        }
        .onTapGesture {
            urlFieldFocused = false
        }
    }

    private func webBase(from apiBase: URL) -> URL {
        if var comps = URLComponents(url: apiBase, resolvingAgainstBaseURL: false) {
            if comps.path.hasSuffix("/api") {
                comps.path = String(comps.path.dropLast(4))
                if let url = comps.url { return url }
            }
        }
        return apiBase.deletingLastPathComponent()
    }

    private func addInstance() {
        guard !isConnecting else { return }
        guard let normalizedURL = normalizedBaseURL(from: urlString) else {
            errorMessage = "Please enter a valid URL."
            showingError = true
            return
        }

        print("Onboarding: discovery for base \(normalizedURL.absoluteString)")

        isConnecting = true
        Task {
            do {
                let discoveryService = DiscoveryService(httpClient: httpClient)
                let brandingService = BrandingService(httpClient: httpClient)

                let capabilities = try await discoveryService.fetchCapabilities(from: normalizedURL)

                print("Onboarding: capabilities OK, apiBase=\(capabilities.apiBaseURL), features=\(capabilities.features)")

                let branding = try await brandingService.fetchBranding(from: capabilities)

                print("Onboarding: branding OK, endpoint=\(capabilities.brandingEndpoint)")

                let authService = AuthService(httpClient: httpClient)

                let authMethod = InstanceProfile.AuthMethod(from: capabilities.auth.type)
                let themeDTO = ThemeDTO(from: branding)

                let displayName = capabilities.apiBaseURL.host ?? normalizedURL.host ?? "Instance"
                let identifier = UUID()

                let profile = InstanceProfile(
                    id: identifier,
                    displayName: displayName,
                    baseURL: capabilities.apiBaseURL,
                    environment: .prod,
                    authMethod: authMethod,
                    authEndpoints: capabilities.auth.endpoints,
                    featureFlags: capabilities.features,
                    minAppVersion: capabilities.minAppVersion,
                    rateLimits: capabilities.rateLimits,
                    tokenIdentifier: identifier.uuidString,
                    theme: themeDTO
                )

                authService.save(apiKey: apiKey, for: profile)

                await MainActor.run {
                    instanceStore.addInstance(profile)
                    urlString = ""
                    apiKey = ""
                }
            } catch {
                await MainActor.run {
                    urlFieldFocused = false
                }
                try? await Task.sleep(nanoseconds: 300_000_000)
                await MainActor.run {
                    errorMessage = detailedErrorDescription(for: error)
                    showingError = true
                }
            }

            await MainActor.run {
                isConnecting = false
            }
        }
    }

    private func normalizedBaseURL(from input: String) -> URL? {
        var trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)

        // Prepend https if missing a scheme
        if !trimmed.contains("://") {
            trimmed = "https://" + trimmed
        }

        // Attempt to parse with URLComponents
        var resultURL: URL?
        if var components = URLComponents(string: trimmed) {
            // Strip any accidental path/query/fragment like "/api" that users may include
            components.path = ""
            components.query = nil
            components.fragment = nil

            // Normalize casing for consistency
            if let host = components.host, !host.isEmpty {
                components.host = host.lowercased()
            }
            components.scheme = components.scheme?.lowercased()
            resultURL = components.url
        }

        // Fallback: If parsing failed or host is missing, try to extract a plausible domain and build an https URL
        if resultURL == nil || resultURL?.host == nil {
            let withoutScheme = input.trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "^https?://", with: "", options: .regularExpression)
            let domainPattern = "^[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$"
            if let range = withoutScheme.range(of: domainPattern, options: .regularExpression) {
                let domain = String(withoutScheme[range]).lowercased()
                resultURL = URL(string: "https://\(domain)")
            }
        }

        // Temporary diagnostic print
        print("normalizedBaseURL input=\(input) -> result=\(resultURL?.absoluteString ?? "nil")")

        return resultURL
    }

    private func detailedErrorDescription(for error: Error) -> String {
        if let apiError = error as? APIError {
            switch apiError {
            case .serverError(let statusCode, let message):
                return "Server error (status: \(statusCode)). \(message ?? "No details provided.")"
            case .decodingError(let underlying, let bodyPreview):
                if let bodyPreview, !bodyPreview.isEmpty {
                    DebugLogger.error("Decoding error with body preview: \(bodyPreview.prefix(1024))")
                }
                return "Failed to decode response from server."
            case .encodingError(let underlying):
                return "Failed to encode request: \(underlying.localizedDescription)"
            case .networkError(let underlying):
                return "Network error: \(underlying.localizedDescription)"
            case .rateLimited(let retryAfter):
                if let retryAfter {
                    return "Rate limited. Retry after \(retryAfter) seconds."
                }
                return "Rate limited. Please try again soon."
            case .invalidURL:
                return "Invalid URL. Please double-check the address."
            case .unauthorized:
                return "Unauthorized. Please verify your credentials for this instance."
            case .forbidden:
                return "Forbidden. Your account may not have access to this instance."
            case .unknown:
                return "Unknown error. Please try again."
            }
        }

        return error.localizedDescription
    }
}

struct EventsListView: View {
    @EnvironmentObject var instanceStore: InstanceStore
    @EnvironmentObject var appSettings: AppSettings
    @Environment(\.httpClient) private var httpClient
    @Environment(\.theme) private var theme

    @StateObject private var viewModel = EventsListViewModel()
    @State private var repository: RemoteEventRepository?
    @State private var showingNewEvent: Bool = false

    var body: some View {
        NavigationStack {
            Group {
                if let instance = instanceStore.activeInstance, let repository {
                    content(for: instance, repository: repository)
                } else {
                    missingInstanceView
                }
            }
            .navigationTitle("Events")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if viewModel.isLoading {
                        ProgressView()
                    } else {
                        Button(action: {
                            showingNewEvent = true
                        }) {
                            Image(systemName: "plus")
                        }
                        .disabled(instanceStore.activeInstance == nil)
                    }
                }
            }
            .task { await bootstrapIfNeeded() }
            .onChange(of: instanceStore.activeInstance?.id) { _, _ in
                viewModel.events = []
                viewModel.errorMessage = nil
                Task { await bootstrapIfNeeded() }
            }
            .sheet(isPresented: $showingNewEvent) {
                if let repository, let instance = instanceStore.activeInstance {
                    NavigationStack {
                        EventFormView(
                            repository: repository,
                            instance: instance
                        ) { saved in
                            viewModel.apply(event: saved)
                        }
                    }
                }
            }
        }
        .accentColor(theme.accent)
    }

    private func bootstrapIfNeeded() async {
        guard let instance = instanceStore.activeInstance else { return }
        let repository = RemoteEventRepository(
            httpClient: httpClient,
            payloadTimeZoneProvider: { appSettings.timeZone }
        )
        self.repository = repository
        viewModel.setContext(repository: repository, instance: instance)
        await viewModel.load()
    }

    @ViewBuilder
    private func content(for instance: InstanceProfile, repository: RemoteEventRepository) -> some View {
        List {
            if viewModel.isLoading && viewModel.events.isEmpty {
                loadingRow
            }

            if let errorMessage = viewModel.errorMessage {
                errorRow(message: errorMessage)
            }

            if viewModel.events.isEmpty && !viewModel.isLoading {
                emptyState(for: instance)
            }

            ForEach(viewModel.events) { event in
                NavigationLink {
                    EventDetailView(
                        event: event,
                        repository: repository,
                        checkInRepository: RemoteCheckInRepository(httpClient: httpClient),
                        instance: instance,
                        onSave: { updated in
                            viewModel.apply(event: updated)
                        },
                        onDelete: { deleted in
                            viewModel.remove(id: deleted.id)
                        }
                    )
                } label: {
                    EventRow(event: event)
                }
            }
            .onDelete { offsets in
                Task { await viewModel.remove(at: offsets) }
            }
        }
        .refreshable {
            await viewModel.refresh()
        }
    }

    private var loadingRow: some View {
        HStack {
            ProgressView()
            Text("Loading events…")
                .foregroundColor(.secondary)
        }
    }

    private func emptyState(for instance: InstanceProfile) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("No events yet")
                .font(.headline)
            Text("Create your first event to start scheduling for \(instance.displayName).")
                .foregroundColor(.secondary)
            Button(action: {
                showingNewEvent = true
                EventInstrumentation.log(action: "events_list_empty_create", instance: instance)
            }) {
                Label("Create event", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 12)
    }

    private func errorRow(message: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Unable to load events", systemImage: "exclamationmark.triangle")
                .foregroundColor(.red)
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Button(action: { Task { await viewModel.refresh() } }) {
                Label("Retry", systemImage: "arrow.clockwise")
            }
        }
        .padding(.vertical, 8)
    }

    private var missingInstanceView: some View {
        VStack(spacing: 12) {
            Text("Add an instance to manage events.")
                .foregroundColor(.secondary)
            NavigationLink {
                InstanceOnboardingPlaceholder()
            } label: {
                Label("Connect to Planify", systemImage: "link")
            }
        }
    }
}

private struct EventRow: View {
    let event: Event
    @EnvironmentObject private var appSettings: AppSettings
    @EnvironmentObject private var instanceStore: InstanceStore
    
    private func makeAbsoluteURL(_ urlString: String?) -> URL? {
        guard let urlString = urlString, !urlString.isEmpty else { return nil }
        guard let instance = instanceStore.activeInstance else { return nil }
        
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

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Flyer thumbnail
            if let flyerURL = makeAbsoluteURL(event.flyerImageUrl) {
                AsyncImage(url: flyerURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Color.gray.opacity(0.2)
                }
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .center, spacing: 8) {
                    Text(event.name)
                        .font(.headline)
                        .lineLimit(2)
                    Spacer()
                    // Removed publish state badge as requested
                }

                HStack(spacing: 12) {
                    Label(
                        event.formattedDateTime(event.startAt, fallbackTimeZone: appSettings.timeZone),
                        systemImage: "clock"
                    )
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                HStack(spacing: 12) {
                    Label(event.venueDisplayDescription, systemImage: "building.2")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    if let capacity = event.capacity {
                        Label("Cap: \(capacity)", systemImage: "person.3")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct SettingsView: View {
    @EnvironmentObject var instanceStore: InstanceStore
    @EnvironmentObject var appSettings: AppSettings
    @Environment(\.httpClient) private var httpClient
    @Environment(\.theme) private var theme

    @State private var apiKey: String = ""
    @State private var isSaving: Bool = false
    @State private var showingAlert: Bool = false
    @State private var alertMessage: String?
    @State private var selectedTimeZone: String = TimeZone.current.identifier
    @State private var timeZoneQuery: String = ""
    @State private var showingAddServer = false
    @State private var showingEditServer: InstanceProfile?
    @State private var serverToDelete: InstanceProfile?
    @State private var showingDeleteAlert = false

    private var filteredTimeZones: [String] {
        if timeZoneQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return TimeZone.knownTimeZoneIdentifiers.sorted()
        }
        return TimeZone.knownTimeZoneIdentifiers
            .filter { $0.localizedCaseInsensitiveContains(timeZoneQuery) }
            .sorted()
    }

    @ViewBuilder
    private func saveAPIKeyLabel(isSaving: Bool) -> some View {
        if isSaving {
            ProgressView()
                .progressViewStyle(.circular)
        } else {
            Text("Save API Key")
        }
    }

    @ViewBuilder
    private func removeAPIKeyLabel() -> some View {
        Text("Remove API Key")
    }
    
    @ViewBuilder
    private func alertMessageView() -> some View {
        Text(alertMessage ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach(instanceStore.instances) { instance in
                        Button {
                            instanceStore.setActiveInstance(instance.id)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(instance.displayName)
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    Text(instance.baseURL.host ?? instance.baseURL.absoluteString)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                if instanceStore.activeInstanceID == instance.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(theme.accent)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                serverToDelete = instance
                                showingDeleteAlert = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            
                            Button {
                                showingEditServer = instance
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            .tint(.blue)
                        }
                        .contextMenu {
                            Button {
                                instanceStore.setActiveInstance(instance.id)
                            } label: {
                                Label("Switch to This Server", systemImage: "arrow.right.circle")
                            }
                            .disabled(instanceStore.activeInstanceID == instance.id)
                            
                            Button {
                                showingEditServer = instance
                            } label: {
                                Label("Edit Server", systemImage: "pencil")
                            }
                            
                            Divider()
                            
                            Button(role: .destructive) {
                                serverToDelete = instance
                                showingDeleteAlert = true
                            } label: {
                                Label("Delete Server", systemImage: "trash")
                            }
                        }
                    }
                    
                    Button {
                        showingAddServer = true
                    } label: {
                        Label("Add Server", systemImage: "plus.circle")
                    }
                } header: {
                    Text("Servers")
                } footer: {
                    Text("Tap a server to switch to it. Swipe to delete.")
                }
                
                if let instance = instanceStore.activeInstance {
                    Section("Active Server Details") {
                        LabeledContent("Name", value: instance.displayName)
                        LabeledContent("URL", value: instance.baseURL.absoluteString)
                        LabeledContent("Environment", value: instance.environment.rawValue)
                        LabeledContent("Auth Method", value: instance.authMethod.rawValue)
                    }

                    Section("API Key") {
                        SecureField("API Key", text: $apiKey)
                            .textInputAutocapitalization(.never)
                    }

                    Section("API Key Session") {
                        sessionSummary(for: instance)

                        Button(action: { saveAPIKey(instance: instance) }) {
                            saveAPIKeyLabel(isSaving: isSaving)
                        }
                        .disabled(apiKey.isEmpty || isSaving)

                        Button(role: .destructive, action: { removeAPIKey(instance: instance) }) {
                            removeAPIKeyLabel()
                        }
                    }

                } else {
                    Section {
                        Text("Add a server to get started.")
                            .foregroundColor(.secondary)
                    }
                }

                Section("Localization") {
                    TextField("Search time zones", text: $timeZoneQuery)
                        .textInputAutocapitalization(.never)

                    Picker("Local Time Zone", selection: $selectedTimeZone) {
                        ForEach(filteredTimeZones, id: \.self) { identifier in
                            if let zone = TimeZone(identifier: identifier) {
                                let offsetHours = Double(zone.secondsFromGMT()) / 3600.0
                                let offset = String(format: "%+.1f", offsetHours)
                                Text("\(zone.identifier) (UTC\(offset))")
                                    .tag(identifier)
                            }
                        }
                    }

                    Button("Reset to Device Time Zone") {
                        appSettings.resetTimeZoneToCurrent()
                        selectedTimeZone = appSettings.timeZoneIdentifier
                    }
                    .disabled(selectedTimeZone == TimeZone.current.identifier)

                    Text("Local time zone is used when saving event start and end times.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
            .tint(theme.primary)
            .navigationTitle("Settings")
            .sheet(isPresented: $showingAddServer) {
                ServerFormView(onSave: { /* Refresh handled by InstanceStore */ })
                    .environmentObject(instanceStore)
                    .environment(\.theme, theme)
            }
            .sheet(item: $showingEditServer) { server in
                ServerFormView(server: server, onSave: { /* Refresh handled by InstanceStore */ })
                    .environmentObject(instanceStore)
                    .environment(\.theme, theme)
            }
            .alert("Delete Server", isPresented: $showingDeleteAlert, presenting: serverToDelete) { server in
                Button("Cancel", role: .cancel) {
                    serverToDelete = nil
                }
                Button("Delete", role: .destructive) {
                    instanceStore.removeInstance(server.id)
                    serverToDelete = nil
                }
            } message: { server in
                Text("Are you sure you want to delete \(server.displayName)? This will remove all saved authentication data for this server.")
            }
            .onAppear {
                selectedTimeZone = appSettings.timeZoneIdentifier
            }
            .onChange(of: selectedTimeZone) { _, newValue in
                appSettings.timeZoneIdentifier = newValue
            }
            .alert("Authentication", isPresented: $showingAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                alertMessageView()
            }
        }
    }

    @ViewBuilder
    private func sessionSummary(for instance: InstanceProfile) -> some View {
        if APIKeyStore.shared.load(for: instance) != nil {
            Text("API Key is saved")
        } else {
            Text("No API Key saved")
                .foregroundColor(.secondary)
        }
    }

    private func saveAPIKey(instance: InstanceProfile) {
        guard !isSaving else { return }
        isSaving = true
        
        let normalizedAPI = normalizeToAPIRoot(instance.baseURL)
        var targetInstance = instance
        if normalizedAPI != instance.baseURL {
            let updated = InstanceProfile(
                id: instance.id,
                displayName: instance.displayName,
                baseURL: normalizedAPI,
                environment: instance.environment,
                authMethod: instance.authMethod,
                authEndpoints: instance.authEndpoints,
                featureFlags: instance.featureFlags,
                minAppVersion: instance.minAppVersion,
                rateLimits: instance.rateLimits,
                tokenIdentifier: instance.tokenIdentifier,
                theme: instance.theme
            )
            if let idx = instanceStore.instances.firstIndex(where: { $0.id == instance.id }) {
                var copies = instanceStore.instances
                copies[idx] = updated
                instanceStore.setInstances(copies)
                instanceStore.setActiveInstance(updated.id)
            }
            targetInstance = updated
        }
        
        let authService = AuthService(httpClient: httpClient)
        authService.save(apiKey: apiKey, for: targetInstance)
        
        if normalizedAPI != instance.baseURL {
            alertMessage = "API Key saved successfully. Normalized API base URL to \(targetInstance.baseURL.absoluteString)."
        } else {
            alertMessage = "API Key saved successfully."
        }
        showingAlert = true
        isSaving = false
    }

    private func removeAPIKey(instance: InstanceProfile) {
        let authService = AuthService(httpClient: httpClient)
        authService.clear(for: instance)
        alertMessage = "API Key removed."
        showingAlert = true
    }

    private func normalizeToAPIRoot(_ url: URL) -> URL {
        let trimmedPath = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if trimmedPath.lowercased() == "api" { return url }
        if url.lastPathComponent.lowercased() == "api" { return url }
        if var comps = URLComponents(url: url, resolvingAgainstBaseURL: false) {
            let basePath = comps.path
            let sanitizedBase = basePath.hasSuffix("/") ? String(basePath.dropLast()) : basePath
            comps.path = sanitizedBase + "/api"
            if let normalized = comps.url { return normalized }
        }
        return url.appendingPathComponent("api")
    }
}

// Extend or add EventFormView helper for webBaseURL usage update
extension EventFormView {
    private func webBaseURL(for instance: InstanceProfile) -> URL {
        return instance.baseURL
    }
}
