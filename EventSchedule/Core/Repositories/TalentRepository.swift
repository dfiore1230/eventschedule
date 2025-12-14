import Foundation

protocol TalentRepositoryProtocol {
    func fetchAll(instance: InstanceProfile) async throws -> [Talent]
    func fetch(id: String, instance: InstanceProfile) async throws -> Talent
    func create(_ talent: Talent, instance: InstanceProfile) async throws -> Talent
    func update(_ talent: Talent, instance: InstanceProfile) async throws -> Talent
    func delete(id: String, instance: InstanceProfile) async throws
}

final class RemoteTalentRepository: TalentRepositoryProtocol {
    private let httpClient: HTTPClientProtocol
    
    init(httpClient: HTTPClientProtocol) {
        self.httpClient = httpClient
    }
    
    func fetchAll(instance: InstanceProfile) async throws -> [Talent] {
        let url = instance.baseURL.appendingPathComponent("/api/talent")
        let data = try await httpClient.get(url: url, instance: instance)
        
        // Try to decode as array directly first
        if let talent = try? JSONDecoder.iso8601.decode([Talent].self, from: data) {
            return talent
        }
        
        // Try to decode as wrapped response with 'data' key
        struct Response: Decodable {
            let data: [Talent]
        }
        
        let response = try JSONDecoder.iso8601.decode(Response.self, from: data)
        return response.data
    }
    
    func fetch(id: String, instance: InstanceProfile) async throws -> Talent {
        let url = instance.baseURL.appendingPathComponent("/api/talent/\(id)")
        let data = try await httpClient.get(url: url, instance: instance)
        return try JSONDecoder.iso8601.decode(Talent.self, from: data)
    }
    
    func create(_ talent: Talent, instance: InstanceProfile) async throws -> Talent {
        let url = instance.baseURL.appendingPathComponent("/api/talent")
        let body = try JSONEncoder.iso8601.encode(talent)
        let data = try await httpClient.post(url: url, body: body, instance: instance)
        return try JSONDecoder.iso8601.decode(Talent.self, from: data)
    }
    
    func update(_ talent: Talent, instance: InstanceProfile) async throws -> Talent {
        let url = instance.baseURL.appendingPathComponent("/api/talent/\(talent.id)")
        let body = try JSONEncoder.iso8601.encode(talent)
        let data = try await httpClient.put(url: url, body: body, instance: instance)
        return try JSONDecoder.iso8601.decode(Talent.self, from: data)
    }
    
    func delete(id: String, instance: InstanceProfile) async throws {
        let url = instance.baseURL.appendingPathComponent("/api/talent/\(id)")
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
