import Foundation

struct DiscoveryService {
    let httpClient: HTTPClientProtocol

    func fetchCapabilities(from baseURL: URL) async throws -> CapabilitiesDocument {
        let bootstrapInstance = InstanceProfile(
            id: UUID(),
            displayName: baseURL.host ?? "Instance",
            baseURL: baseURL,
            environment: .prod,
            authMethod: .sanctum,
            authEndpoints: nil,
            featureFlags: [:],
            minAppVersion: nil,
            rateLimits: nil,
            tokenIdentifier: nil,
            theme: ThemeDTO.default
        )

        return try await httpClient.request(
            "/.well-known/planify.json",
            method: .get,
            query: nil,
            body: nil,
            instance: bootstrapInstance
        )
    }
}
