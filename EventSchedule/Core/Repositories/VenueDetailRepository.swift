import Foundation

protocol VenueDetailRepositoryProtocol {
    func fetchAll(instance: InstanceProfile) async throws -> [VenueDetail]
    func fetch(id: String, instance: InstanceProfile) async throws -> VenueDetail
    func create(_ venue: VenueDetail, instance: InstanceProfile) async throws -> VenueDetail
    func update(_ venue: VenueDetail, instance: InstanceProfile) async throws -> VenueDetail
    func delete(id: String, instance: InstanceProfile) async throws
}

final class RemoteVenueDetailRepository: VenueDetailRepositoryProtocol {
    private let httpClient: HTTPClientProtocol
    
    init(httpClient: HTTPClientProtocol) {
        self.httpClient = httpClient
    }
    
    func fetchAll(instance: InstanceProfile) async throws -> [VenueDetail] {
        // Try direct array first
        if let direct: [VenueDetail] = try? await httpClient.request(
            "api/venues",
            method: .get,
            query: nil,
            body: Optional<VenueDetail>.none,
            instance: instance
        ) {
            return direct
        }
        // Fallback to wrapped response { data: [VenueDetail] }
        struct Response: Decodable { let data: [VenueDetail] }
        let wrapped: Response = try await httpClient.request(
            "api/venues",
            method: .get,
            query: nil,
            body: Optional<VenueDetail>.none,
            instance: instance
        )
        return wrapped.data
    }
    
    func fetch(id: String, instance: InstanceProfile) async throws -> VenueDetail {
        let venue: VenueDetail = try await httpClient.request(
            "api/venues/\(id)",
            method: .get,
            query: nil,
            body: Optional<VenueDetail>.none,
            instance: instance
        )
        return venue
    }
    
    func create(_ venue: VenueDetail, instance: InstanceProfile) async throws -> VenueDetail {
        let created: VenueDetail = try await httpClient.request(
            "api/venues",
            method: .post,
            query: nil,
            body: venue,
            instance: instance
        )
        return created
    }
    
    func update(_ venue: VenueDetail, instance: InstanceProfile) async throws -> VenueDetail {
        let updated: VenueDetail = try await httpClient.request(
            "api/venues/\(venue.id)",
            method: .put,
            query: nil,
            body: venue,
            instance: instance
        )
        return updated
    }
    
    func delete(id: String, instance: InstanceProfile) async throws {
        try await httpClient.requestVoid(
            "api/venues/\(id)",
            method: .delete,
            query: nil,
            body: Optional<VenueDetail>.none,
            instance: instance
        )
    }
}
