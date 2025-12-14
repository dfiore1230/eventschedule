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
        let url = instance.baseURL.appendingPathComponent("/api/venues")
        let data = try await httpClient.get(url: url, instance: instance)
        
        // Try to decode as array directly first
        if let venues = try? JSONDecoder.iso8601.decode([VenueDetail].self, from: data) {
            return venues
        }
        
        // Try to decode as wrapped response with 'data' key
        struct Response: Decodable {
            let data: [VenueDetail]
        }
        
        let response = try JSONDecoder.iso8601.decode(Response.self, from: data)
        return response.data
    }
    
    func fetch(id: String, instance: InstanceProfile) async throws -> VenueDetail {
        let url = instance.baseURL.appendingPathComponent("/api/venues/\(id)")
        let data = try await httpClient.get(url: url, instance: instance)
        return try JSONDecoder.iso8601.decode(VenueDetail.self, from: data)
    }
    
    func create(_ venue: VenueDetail, instance: InstanceProfile) async throws -> VenueDetail {
        let url = instance.baseURL.appendingPathComponent("/api/venues")
        let body = try JSONEncoder.iso8601.encode(venue)
        let data = try await httpClient.post(url: url, body: body, instance: instance)
        return try JSONDecoder.iso8601.decode(VenueDetail.self, from: data)
    }
    
    func update(_ venue: VenueDetail, instance: InstanceProfile) async throws -> VenueDetail {
        let url = instance.baseURL.appendingPathComponent("/api/venues/\(venue.id)")
        let body = try JSONEncoder.iso8601.encode(venue)
        let data = try await httpClient.put(url: url, body: body, instance: instance)
        return try JSONDecoder.iso8601.decode(VenueDetail.self, from: data)
    }
    
    func delete(id: String, instance: InstanceProfile) async throws {
        let url = instance.baseURL.appendingPathComponent("/api/venues/\(id)")
        _ = try await httpClient.delete(url: url, instance: instance)
    }
}

// Convenience extensions for JSONDecoder and JSONEncoder
private extension JSONDecoder {
    static let iso8601: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}

private extension JSONEncoder {
    static let iso8601: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
}
