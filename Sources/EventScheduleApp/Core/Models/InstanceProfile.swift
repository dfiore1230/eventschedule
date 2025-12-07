import Foundation

enum InstanceEnvironment: String, Codable, CaseIterable {
    case prod
    case staging
    case dev
}

struct InstanceProfile: Identifiable, Codable, Equatable {
    let id: UUID
    var displayName: String
    var baseURL: URL
    var environment: InstanceEnvironment
    var authMethod: AuthMethod
    var featureFlags: [String: Bool]
    var minAppVersion: String?
    var rateLimits: [String: Int]?
    var tokenIdentifier: String?

    enum AuthMethod: String, Codable {
        case sanctum
        case oauth2
        case jwt
    }
}
