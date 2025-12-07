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
        case apiBaseURLCamel = "apiBaseURL"
        case auth
        case brandingEndpoint = "branding_endpoint"
        case brandingEndpointCamel = "brandingEndpoint"
        case legacyBrandingEndpoint = "brandingendpoint"
        case features
        case versions
        case minAppVersion = "min_app_version"
        case rateLimits = "rate_limits"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let apiBaseURLString = try container.decodeIfPresent(String.self, forKey: .apiBaseURLCamel)
            ?? container.decode(String.self, forKey: .apiBaseURL)
        guard let resolvedAPIBase = URL(string: apiBaseURLString) else {
            throw DecodingError.dataCorruptedError(forKey: .apiBaseURL, in: container, debugDescription: "Invalid api_base_url")
        }
        apiBaseURL = resolvedAPIBase

        let authContainer = try container.nestedContainer(keyedBy: AuthCodingKeys.self, forKey: .auth)
        let authType = try authContainer.decode(AuthConfig.AuthType.self, forKey: .type)
        let authEndpointStrings = try authContainer.decodeIfPresent([String: String].self, forKey: .endpoints) ?? [:]
        let resolvedAuthEndpoints = authEndpointStrings.compactMapValues { endpoint in
            CapabilitiesDocument.resolveURL(endpoint, base: resolvedAPIBase)
        }
        auth = AuthConfig(type: authType, endpoints: resolvedAuthEndpoints)

        let brandingString = try container.decodeIfPresent(String.self, forKey: .brandingEndpointCamel)
            ?? container.decodeIfPresent(String.self, forKey: .brandingEndpoint)
            ?? container.decodeIfPresent(String.self, forKey: .legacyBrandingEndpoint)
        if let brandingString = brandingString,
           let resolvedEndpoint = CapabilitiesDocument.resolveURL(brandingString, base: resolvedAPIBase) {
            brandingEndpoint = resolvedEndpoint
        } else {
            throw DecodingError.dataCorruptedError(forKey: .brandingEndpoint, in: container, debugDescription: "Invalid branding endpoint")
        }

        let featuresDict = try container.decodeIfPresent([String: Bool].self, forKey: .features)
            ?? (try container.decodeIfPresent([String].self, forKey: .features)
                    .map { Dictionary(uniqueKeysWithValues: $0.map { ($0, true) }) })
            ?? [:]
        features = featuresDict

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
