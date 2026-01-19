import SwiftUI

struct RootView: View {
    @EnvironmentObject var instanceStore: InstanceStore
    @Environment(\.theme) private var theme

    var body: some View {
        Group {
            if instanceStore.activeInstance == nil {
                InstanceOnboardingPlaceholder()
            } else {
                MainTabView()
            }
        }
        .accentColor(theme.accent)
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }
}

struct MainTabView: View {
    @Environment(\.theme) private var theme

    var body: some View {
        TabView {
            EventsListView()
                .tabItem {
                    Label("Events", systemImage: "calendar")
                }
            
            TalentListView()
                .tabItem {
                    Label("Talent", systemImage: "person.3")
                }
            
            VenueListView()
                .tabItem {
                    Label("Venues", systemImage: "building.2")
                }
            
            TicketListView()
                .tabItem {
                    Label("Tickets", systemImage: "ticket")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
        .tint(theme.primary)
    }
}
