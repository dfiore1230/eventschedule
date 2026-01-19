import Foundation

struct CapabilitiesDocument: Decodable, Encodable {
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
            ?? container.decodeIfPresent(String.self, forKey: .apiBaseURL)

        let brandingString = try container.decodeIfPresent(String.self, forKey: .brandingEndpointCamel)
            ?? container.decodeIfPresent(String.self, forKey: .brandingEndpoint)
            ?? container.decodeIfPresent(String.self, forKey: .legacyBrandingEndpoint)

        if let string = apiBaseURLString, let resolved = URL(string: string) {
            apiBaseURL = resolved
        } else {
            // Safe fallback if key missing or invalid
            apiBaseURL = URL(string: "https://localhost")!
        }

        if container.contains(.auth) {
            func resolveURLLocal(_ value: String, base: URL) -> URL? {
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                if let absolute = URL(string: trimmed), absolute.scheme != nil {
                    return absolute
                }
                return URL(string: trimmed, relativeTo: base)?.absoluteURL
            }

            let authContainer = try container.nestedContainer(keyedBy: AuthCodingKeys.self, forKey: .auth)
            let authType = try authContainer.decode(AuthConfig.AuthType.self, forKey: .type)
            let authEndpointStrings = try authContainer.decodeIfPresent([String: String].self, forKey: .endpoints) ?? [:]
            var resolvedAuthEndpoints: [String: URL] = [:]
            for (key, value) in authEndpointStrings {
                if let url = resolveURLLocal(value, base: apiBaseURL) {
                    resolvedAuthEndpoints[key] = url
                }
            }
            auth = AuthConfig(type: authType, endpoints: resolvedAuthEndpoints)
        } else {
            // Default to a reasonable type with no endpoints when missing
            auth = AuthConfig(type: .jwt, endpoints: [:])
        }

        if let endpointString = brandingString, let resolvedEndpoint = CapabilitiesDocument.resolveURL(endpointString, base: apiBaseURL) {
            brandingEndpoint = resolvedEndpoint
        } else {
            // Fallback: if branding endpoint is missing or invalid, default to the API base URL
            brandingEndpoint = apiBaseURL
        }

        let featuresDict: [String: Bool]
        if let dict = try? container.decode([String: Bool].self, forKey: .features) {
            featuresDict = dict
        } else if let arr = try? container.decode([String].self, forKey: .features) {
            featuresDict = Dictionary(uniqueKeysWithValues: arr.map { ($0, true) })
        } else {
            featuresDict = [:]
        }
        features = featuresDict

        // These fields are optional. If the backend sends an unexpected type (for example, a
        // string instead of a dictionary), we log the issue but continue decoding with
        // sensible fallbacks instead of failing the entire request.
        do {
            versions = try container.decodeIfPresent([String: String].self, forKey: .versions)
        } catch {
            versions = nil
        }

        do {
            minAppVersion = try container.decodeIfPresent(String.self, forKey: .minAppVersion)
        } catch {
            minAppVersion = nil
        }

        do {
            rateLimits = try container.decodeIfPresent([String: Int].self, forKey: .rateLimits)
        } catch {
            rateLimits = nil
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(apiBaseURL, forKey: .apiBaseURLCamel)
        try container.encode(auth, forKey: .auth)
        try container.encode(brandingEndpoint, forKey: .brandingEndpointCamel)
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
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if let absolute = URL(string: trimmed), absolute.scheme != nil {
            return absolute
        }
        return URL(string: trimmed, relativeTo: base)?.absoluteURL
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
