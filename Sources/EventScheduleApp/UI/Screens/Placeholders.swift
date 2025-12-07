import SwiftUI

struct InstanceOnboardingPlaceholder: View {
    @EnvironmentObject var instanceStore: InstanceStore
    @Environment(\.theme) private var theme

    @State private var urlString: String = ""

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
                }
                .disabled(urlString.isEmpty)

                Spacer()
            }
            .padding()
            .navigationTitle("EventSchedule")
        }
    }

    private func addInstance() {
        guard let url = URL(string: urlString) else { return }

        let profile = InstanceProfile(
            id: UUID(),
            displayName: url.host ?? "Instance",
            baseURL: url,
            environment: .prod,
            authMethod: .sanctum,
            featureFlags: [:],
            minAppVersion: nil,
            rateLimits: nil,
            tokenIdentifier: nil
        )
        instanceStore.addInstance(profile)
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
