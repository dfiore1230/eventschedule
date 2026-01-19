import SwiftUI

@main
struct EventScheduleApp: App {
    @StateObject private var instanceStore = InstanceStore()
    @StateObject private var authStore = AuthTokenStore.shared
    @StateObject private var appSettings = AppSettings.shared
    @State private var httpClient: HTTPClient

    init() {
        _httpClient = State(initialValue: HTTPClient(tokenProvider: { instance in
            AuthTokenStore.shared.token(for: instance)
        }))
    }

    var body: some Scene {
        WindowGroup {
            ThemeProvider(instanceStore: instanceStore) {
                RootView()
                    .environmentObject(instanceStore)
                    .environmentObject(authStore)
                    .environmentObject(appSettings)
                    .environment(\.httpClient, httpClient)
            }
        }
    }
}
