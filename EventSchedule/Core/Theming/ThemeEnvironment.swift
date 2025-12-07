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
        if instanceStore.activeInstance != nil {
            theme = .default // TODO: Load per-instance theme
        } else {
            theme = .default
        }

        return content()
            .environment(\.theme, theme)
    }
}
