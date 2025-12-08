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
                    Text("Add an EventSchedule Instance")
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
            .navigationTitle("EventSchedule")
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
                    return "Failed to decode response: \(bodyPreview)"
                }
                return "Failed to decode response: \(underlying.localizedDescription)"
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
                        Button(action: { showingNewEvent = true }) {
                            Image(systemName: "plus")
                        }
                        .disabled(instanceStore.activeInstance == nil)
                    }
                }
            }
            .task { await bootstrapIfNeeded() }
            .onChange(of: instanceStore.activeInstance?.id) { _ in
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
        let repository = RemoteEventRepository(httpClient: httpClient)
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
                    EventDetailView(event: event, repository: repository, instance: instance) { updated in
                        viewModel.apply(event: updated)
                    }
                } label: {
                    EventRow(event: event)
                }
            }
            .onDelete { offsets in
                Task { await viewModel.remove(at: offsets) }
            }
        }
        .refreshable { await viewModel.refresh() }
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
            Button(action: { showingNewEvent = true }) {
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
                Label("Connect to EventSchedule", systemImage: "link")
            }
        }
    }
}

private struct EventRow: View {
    let event: Event

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 8) {
                Text(event.name)
                    .font(.headline)
                    .lineLimit(2)
                Spacer()
                StatusBadge(title: event.publishState.rawValue.capitalized, style: .publish(event.publishState))
            }

            HStack(spacing: 12) {
                Label(event.startAt.formatted(date: .abbreviated, time: .shortened), systemImage: "clock")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Label(event.status.rawValue.capitalized, systemImage: "bolt.horizontal")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 12) {
                Label(event.venueId.isEmpty ? "Unknown venue" : event.venueId, systemImage: "building.2")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                if let capacity = event.capacity {
                    Label("Cap: \(capacity)", systemImage: "person.3")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct StatusBadge: View {
    enum Style {
        case publish(PublishState)
        case status(EventStatus)
    }

    let title: String
    let style: Style

    var body: some View {
        Text(title)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(backgroundColor)
            .foregroundColor(foregroundColor)
            .clipShape(Capsule())
    }

    private var backgroundColor: Color {
        switch style {
        case .publish(let state):
            switch state {
            case .published: return Color.green.opacity(0.15)
            case .draft: return Color.gray.opacity(0.15)
            case .archived: return Color.orange.opacity(0.15)
            }
        case .status(let status):
            switch status {
            case .scheduled: return Color.blue.opacity(0.15)
            case .ongoing: return Color.green.opacity(0.15)
            case .completed: return Color.purple.opacity(0.15)
            case .cancelled: return Color.red.opacity(0.15)
            }
        }
    }

    private var foregroundColor: Color {
        switch style {
        case .publish(let state):
            switch state {
            case .published: return .green
            case .draft: return .gray
            case .archived: return .orange
            }
        case .status(let status):
            switch status {
            case .scheduled: return .blue
            case .ongoing: return .green
            case .completed: return .purple
            case .cancelled: return .red
            }
        }
    }
}
struct SettingsView: View {
    @EnvironmentObject var instanceStore: InstanceStore
    @Environment(\.httpClient) private var httpClient
    @Environment(\.theme) private var theme

    @State private var apiKey: String = ""
    @State private var isSaving: Bool = false
    @State private var showingAlert: Bool = false
    @State private var alertMessage: String?

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
                if let instance = instanceStore.activeInstance {
                    Section("Active Instance") {
                        Text(instance.displayName)
                        Text(instance.baseURL.absoluteString)
                            .font(.footnote)
                            .foregroundColor(.secondary)
                        Text("Auth method: \(instance.authMethod.rawValue)")
                            .font(.footnote)
                            .foregroundColor(.secondary)
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
                        Text("Add an instance to configure authentication.")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .tint(theme.primary)
            .navigationTitle("Settings")
            .toolbar {
                InstanceSwitcherToolbarItem()
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

        let authService = AuthService(httpClient: httpClient)
        authService.save(apiKey: apiKey, for: instance)
        alertMessage = "API Key saved successfully."
        showingAlert = true
        isSaving = false
    }

    private func removeAPIKey(instance: InstanceProfile) {
        let authService = AuthService(httpClient: httpClient)
        authService.clear(for: instance)
        alertMessage = "API Key removed."
        showingAlert = true
    }
}

