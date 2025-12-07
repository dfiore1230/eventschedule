import SwiftUI

private struct AuthStoreKey: EnvironmentKey {
    static let defaultValue: AuthTokenStore = .shared
}

extension EnvironmentValues {
    var authStore: AuthTokenStore {
        get { self[AuthStoreKey.self] }
        set { self[AuthStoreKey.self] = newValue }
    }
}
