import SwiftUI

struct InstanceOnboardingPlaceholder: View {
    @EnvironmentObject var instanceStore: InstanceStore
    @Environment(\.theme) private var theme
    @Environment(\.httpClient) private var httpClient

    @State private var urlString: String = ""
    @State private var isConnecting: Bool = false
    @State private var errorMessage: String?
    @State private var showingError: Bool = false

    var body: some View {
        NavigationStack {
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
                .disabled(urlString.isEmpty || isConnecting)

                Spacer()
            }
            .padding()
            .navigationTitle("EventSchedule")
            .alert("Connection Failed", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage ?? "Unknown error")
            }
        }
    }

    private func addInstance() {
        guard !isConnecting else { return }
        guard let normalizedURL = normalizedBaseURL(from: urlString) else {
            errorMessage = "Please enter a valid URL."
            showingError = true
            return
        }

        isConnecting = true
        Task {
            do {
                let discoveryService = DiscoveryService(httpClient: httpClient)
                let brandingService = BrandingService(httpClient: httpClient)

                let capabilities = try await discoveryService.fetchCapabilities(from: normalizedURL)
                let branding = try await brandingService.fetchBranding(from: capabilities)

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

                await MainActor.run {
                    instanceStore.addInstance(profile)
                    urlString = ""
                }
            } catch {
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
        if !trimmed.contains("://") {
            trimmed = "https://" + trimmed
        }

        guard var components = URLComponents(string: trimmed) else { return nil }
        components.path = ""
        components.query = nil
        components.fragment = nil
        return components.url
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

struct DashboardView: View {
    @EnvironmentObject var instanceStore: InstanceStore

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                if let instance = instanceStore.activeInstance {
                    Text("Dashboard")
                        .font(.title)
                    Text("Instance: \(instance.displayName)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                } else {
                    Text("No active instance.")
                }
                Spacer()
            }
            .padding()
            .navigationTitle("Dashboard")
            .toolbar {
                InstanceSwitcherToolbarItem()
            }
        }
    }
}

struct EventsListView: View {
    var body: some View {
        NavigationStack {
            Text("Events")
                .navigationTitle("Events")
                .toolbar {
                    InstanceSwitcherToolbarItem()
                }
        }
    }
}

struct TalentListView: View {
    var body: some View {
        NavigationStack {
            Text("Talent")
                .navigationTitle("Talent")
                .toolbar {
                    InstanceSwitcherToolbarItem()
                }
        }
    }
}

struct VenuesListView: View {
    var body: some View {
        NavigationStack {
            Text("Venues")
                .navigationTitle("Venues")
                .toolbar {
                    InstanceSwitcherToolbarItem()
                }
        }
    }
}

struct TicketsSearchView: View {
    var body: some View {
        NavigationStack {
            Text("Tickets")
                .navigationTitle("Tickets")
                .toolbar {
                    InstanceSwitcherToolbarItem()
                }
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject var instanceStore: InstanceStore
    @EnvironmentObject var authStore: AuthTokenStore
    @Environment(\.httpClient) private var httpClient
    @Environment(\.theme) private var theme

    @State private var email: String = ""
    @State private var password: String = ""
    @State private var isLoggingIn: Bool = false
    @State private var showingAlert: Bool = false
    @State private var alertMessage: String?

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

                    Section("Credentials") {
                        TextField("Email or username", text: $email)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()

                        SecureField("Password", text: $password)
                    }

                    Section("Session") {
                        sessionSummary(for: instance)

                        Button(action: { login(instance: instance) }) {
                            if isLoggingIn {
                                ProgressView()
                                    .progressViewStyle(.circular)
                            } else {
                                Text("Log In")
                                    .frame(maxWidth: .infinity, alignment: .center)
                            }
                        }
                        .disabled(email.isEmpty || password.isEmpty || isLoggingIn)

                        Button(role: .destructive, action: { logout(instance: instance) }) {
                            Text("Log Out")
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                        .disabled(authStore.session(for: instance) == nil)
                    }
                } else {
                    Section {
                        Text("Add an instance to configure authentication.")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                InstanceSwitcherToolbarItem()
            }
            .tint(theme.primary)
            .alert("Authentication", isPresented: $showingAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(alertMessage ?? "")
            }
        }
    }

    @ViewBuilder
    private func sessionSummary(for instance: InstanceProfile) -> some View {
        if let session = authStore.session(for: instance) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Session active")
                if let expiry = session.expiryDate {
                    Text("Expires: \(expiry.formatted(date: .abbreviated, time: .shortened))")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
        } else {
            Text("Not logged in")
                .foregroundColor(.secondary)
        }
    }

    private func login(instance: InstanceProfile) {
        guard !isLoggingIn else { return }
        isLoggingIn = true

        Task {
            do {
                let authService = AuthService(httpClient: httpClient)
                let session = try await authService.login(email: email, password: password, instance: instance)

                await MainActor.run {
                    authStore.save(session: session, for: instance)
                    alertMessage = "Logged in successfully."
                    showingAlert = true
                }
            } catch {
                await MainActor.run {
                    alertMessage = error.localizedDescription
                    showingAlert = true
                }
            }

            await MainActor.run {
                isLoggingIn = false
            }
        }
    }

    private func logout(instance: InstanceProfile) {
        authStore.clearSession(for: instance)
        alertMessage = "Logged out."
        showingAlert = true
    }
}

