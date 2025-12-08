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
            case .decodingError(let underlying):
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

    @StateObject private var viewModel: EventsListViewModel = .init()
    @State private var repository: RemoteEventRepository?
    @State private var showingCreateForm: Bool = false

    var body: some View {
        NavigationStack {
            Group {
                mainContent()
            }
            .navigationTitle("Events")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingCreateForm = true }) {
                        Image(systemName: "plus")
                    }
                    .disabled(instanceStore.activeInstance == nil)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    InstanceSwitcherToolbarItem()
                }
            }
            .onAppear {
                if repository == nil {
                    repository = RemoteEventRepository(httpClient: httpClient)
                }
            }
            .sheet(isPresented: $showingCreateForm) { createEventSheet() }
            .accentColor(theme.accent)
        }
    }

    private func eventRow(_ event: Event) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(event.name)
                .font(.headline)
            Text(event.startAt.formatted(date: .abbreviated, time: .shortened))
                .font(.subheadline)
                .foregroundColor(.secondary)
            Text(event.venueId)
                .font(.footnote)
                .foregroundColor(.secondary)
        }
    }

    @ViewBuilder
    private func eventsList(for instance: InstanceProfile, repository repo: RemoteEventRepository) -> some View {
        List {
            ForEach(viewModel.events) { event in
                NavigationLink {
                    EventDetailView(event: event, repository: repo, instance: instance) { updated in
                        viewModel.apply(event: updated)
                    }
                } label: {
                    eventRow(event)
                }
            }
            .onDelete { offsets in
                Task { await viewModel.remove(at: offsets) }
            }
        }
        .listStyle(.plain)
        .overlay(alignment: .center) {
            eventsOverlay()
        }
        .task {
            viewModel.setContext(repository: repo, instance: instance)
            await viewModel.load()
        }
        .refreshable {
            await viewModel.refresh()
        }
    }

    @ViewBuilder
    private func eventsOverlay() -> some View {
        if viewModel.isLoading {
            ProgressView("Loading Events…")
        } else if let message = viewModel.errorMessage, viewModel.events.isEmpty {
            VStack(spacing: 8) {
                Text("Could not load events")
                    .font(.headline)
                Text(message)
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
            .multilineTextAlignment(.center)
            .padding()
        } else if viewModel.events.isEmpty {
            Text("No events found")
                .foregroundColor(.secondary)
        }
    }

    @ViewBuilder
    private func mainContent() -> some View {
        if let instance = instanceStore.activeInstance, let repo = repository {
            eventsList(for: instance, repository: repo)
        } else {
            Text("Add an instance to start browsing events.")
                .foregroundColor(.secondary)
                .padding()
        }
    }

    @ViewBuilder
    private func createEventSheet() -> some View {
        if let instance = instanceStore.activeInstance, let repo = repository {
            NavigationStack {
                EventFormView(repository: repo, instance: instance) { newEvent in
                    viewModel.apply(event: newEvent)
                }
            }
        } else {
            EmptyView()
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

