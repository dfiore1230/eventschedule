import SwiftUI

@main
struct EventScheduleApp: App {
    @StateObject private var instanceStore = InstanceStore()
    private let httpClient = HTTPClient()

    var body: some Scene {
        WindowGroup {
            ThemeProvider(instanceStore: instanceStore) {
                RootView()
                    .environmentObject(instanceStore)
                    .environment(\.httpClient, httpClient)
            }
        }
    }
}
