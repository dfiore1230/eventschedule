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

        init(type: AuthType, endpoints: [String: URL]) {
            self.type = type
            self.endpoints = endpoints
        }
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
        let apiBaseURLString = try container.decode(String.self, forKey: .apiBaseURL)
        guard let resolvedAPIBase = URL(string: apiBaseURLString) else {
            throw DecodingError.dataCorruptedError(forKey: .apiBaseURL, in: container, debugDescription: "Invalid api_base_url")
        }
        apiBaseURL = resolvedAPIBase

        let authContainer = try container.nestedContainer(keyedBy: AuthCodingKeys.self, forKey: .auth)
        let authType = try authContainer.decode(AuthConfig.AuthType.self, forKey: .type)
        let authEndpointStrings = try authContainer.decode([String: String].self, forKey: .endpoints)
        let resolvedAuthEndpoints = authEndpointStrings.compactMapValues { endpoint in
            resolveURL(endpoint, base: resolvedAPIBase)
        }
        auth = AuthConfig(type: authType, endpoints: resolvedAuthEndpoints)

        if let endpointString = try container.decodeIfPresent(String.self, forKey: .brandingEndpoint) ??
            container.decodeIfPresent(String.self, forKey: .legacyBrandingEndpoint),
           let resolvedEndpoint = resolveURL(endpointString, base: resolvedAPIBase) {
            brandingEndpoint = resolvedEndpoint
        } else {
            throw DecodingError.dataCorruptedError(forKey: .brandingEndpoint, in: container, debugDescription: "Invalid branding endpoint")
        }
        features = try container.decode([String: Bool].self, forKey: .features)
        versions = try container.decodeIfPresent([String: String].self, forKey: .versions)
        minAppVersion = try container.decodeIfPresent(String.self, forKey: .minAppVersion)
        rateLimits = try container.decodeIfPresent([String: Int].self, forKey: .rateLimits)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(apiBaseURL, forKey: .apiBaseURL)
        try container.encode(auth, forKey: .auth)
        try container.encode(brandingEndpoint, forKey: .brandingEndpoint)
        try container.encode(features, forKey: .features)
        try container.encodeIfPresent(versions, forKey: .versions)
        try container.encodeIfPresent(minAppVersion, forKey: .minAppVersion)
        try container.encodeIfPresent(rateLimits, forKey: .rateLimits)
    }
}

private extension CapabilitiesDocument {
    enum AuthCodingKeys: String, CodingKey {
        case type
        case endpoints
    }

    static func resolveURL(_ value: String, base: URL) -> URL? {
        if let absolute = URL(string: value), absolute.scheme != nil {
            return absolute
        }

        return URL(string: value, relativeTo: base)?.absoluteURL
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
