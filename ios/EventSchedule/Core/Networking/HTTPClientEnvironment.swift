import SwiftUI

private struct HTTPClientKey: EnvironmentKey {
    static let defaultValue: HTTPClientProtocol = HTTPClient()
}

extension EnvironmentValues {
    var httpClient: HTTPClientProtocol {
        get { self[HTTPClientKey.self] }
        set { self[HTTPClientKey.self] = newValue }
    }
}
