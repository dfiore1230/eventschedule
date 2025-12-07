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

                let profile = InstanceProfile(
                    id: UUID(),
                    displayName: displayName,
                    baseURL: capabilities.apiBaseURL,
                    environment: .prod,
                    authMethod: authMethod,
                    featureFlags: capabilities.features,
                    minAppVersion: capabilities.minAppVersion,
                    rateLimits: capabilities.rateLimits,
                    tokenIdentifier: nil,
                    theme: themeDTO
                )

                await MainActor.run {
                    instanceStore.addInstance(profile)
                    urlString = ""
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
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
    var body: some View {
        NavigationStack {
            Text("Settings")
                .navigationTitle("Settings")
                .toolbar {
                    InstanceSwitcherToolbarItem()
                }
        }
    }
}
