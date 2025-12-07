import Foundation

struct CapabilitiesDocument: Codable {
    struct AuthConfig: Codable {
        enum AuthType: String, Codable {
            case sanctum
            case passport
            case jwt
        }

        let type: AuthType
        let endpoints: [String: URL]
    }

    let apiBaseURL: URL
    let auth: AuthConfig
    let brandingEndpoint: URL
    let features: [String: Bool]
    let versions: [String: String]?
    let minAppVersion: String?
    let rateLimits: [String: Int]?

    enum CodingKeys: String, CodingKey {
        case apiBaseURL = "api_base_url"
        case auth
        case brandingEndpoint = "brandingendpoint"
        case features
        case versions
        case minAppVersion = "min_app_version"
        case rateLimits = "rate_limits"
    }
}

extension InstanceProfile.AuthMethod {
    init(from authType: CapabilitiesDocument.AuthConfig.AuthType) {
        switch authType {
        case .sanctum:
            self = .sanctum
        case .passport:
            self = .oauth2
        case .jwt:
            self = .jwt
        }
    }
}
