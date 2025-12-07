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
        case brandingEndpoint = "branding_endpoint"
        case legacyBrandingEndpoint = "brandingendpoint"
        case features
        case versions
        case minAppVersion = "min_app_version"
        case rateLimits = "rate_limits"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        apiBaseURL = try container.decode(URL.self, forKey: .apiBaseURL)
        auth = try container.decode(AuthConfig.self, forKey: .auth)
        if let endpoint = try container.decodeIfPresent(URL.self, forKey: .brandingEndpoint) {
            brandingEndpoint = endpoint
        } else {
            brandingEndpoint = try container.decode(URL.self, forKey: .legacyBrandingEndpoint)
        }
        features = try container.decode([String: Bool].self, forKey: .features)
        versions = try container.decodeIfPresent([String: String].self, forKey: .versions)
        minAppVersion = try container.decodeIfPresent(String.self, forKey: .minAppVersion)
        rateLimits = try container.decodeIfPresent([String: Int].self, forKey: .rateLimits)
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
