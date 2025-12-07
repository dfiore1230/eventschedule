import SwiftUI

private struct ThemeKey: EnvironmentKey {
    static let defaultValue: Theme = .default
}

extension EnvironmentValues {
    var theme: Theme {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
}

struct ThemeProvider<Content: View>: View {
    @ObservedObject var instanceStore: InstanceStore
    let content: () -> Content

    var body: some View {
        let theme: Theme
        if let activeInstance = instanceStore.activeInstance {
            theme = Theme(dto: activeInstance.theme)
        } else {
            theme = .default
        }

        return content()
            .environment(\.theme, theme)
    }
}
