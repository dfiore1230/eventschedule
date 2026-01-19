import Foundation

struct BrandingService {
    let httpClient: HTTPClientProtocol

    func fetchBranding(from capabilities: CapabilitiesDocument) async throws -> BrandingResponse {
        let brandingURL = capabilities.brandingEndpoint
        let components = URLComponents(url: brandingURL, resolvingAgainstBaseURL: false)

        let baseURL = brandingURL.deletingLastPathComponent()
        let queryItems = components?.queryItems ?? []
        let query: [String: String?] = Dictionary(uniqueKeysWithValues: queryItems.map { item in
            (item.name, item.value)
        })

        let bootstrapInstance = InstanceProfile(
            id: UUID(),
            displayName: baseURL.host ?? "Instance",
            baseURL: baseURL,
            environment: .prod,
            authMethod: .sanctum,
            authEndpoints: nil,
            featureFlags: capabilities.features,
            minAppVersion: capabilities.minAppVersion,
            rateLimits: capabilities.rateLimits,
            tokenIdentifier: nil,
            theme: ThemeDTO.default
        )

        return try await httpClient.request(
            brandingURL.path,
            method: .get,
            query: query,
            body: nil,
            instance: bootstrapInstance
        )
    }
}
