import Foundation

protocol TalentRepositoryProtocol {
    func fetchAll(instance: InstanceProfile) async throws -> [Talent]
    func fetch(id: Int, instance: InstanceProfile) async throws -> Talent
    func create(_ talent: Talent, instance: InstanceProfile) async throws -> Talent
    func update(_ talent: Talent, instance: InstanceProfile) async throws -> Talent
    func delete(id: Int, instance: InstanceProfile) async throws
}

final class RemoteTalentRepository: TalentRepositoryProtocol {
    private let httpClient: HTTPClientProtocol
    
    init(httpClient: HTTPClientProtocol) {
        self.httpClient = httpClient
    }
    
    func fetchAll(instance: InstanceProfile) async throws -> [Talent] {
        struct Response: Decodable {
            let data: [Talent]
        }
        let response: Response = try await httpClient.request("/api/talent", method: .get, query: nil, body: Optional<Talent>.none, instance: instance)
        return response.data
    }
    
    func fetch(id: Int, instance: InstanceProfile) async throws -> Talent {
        return try await httpClient.request("/api/talent/\(id)", method: .get, query: nil, body: Optional<Talent>.none, instance: instance)
    }
    
    func create(_ talent: Talent, instance: InstanceProfile) async throws -> Talent {
        let created: Talent = try await httpClient.request("/api/talent", method: .post, query: nil, body: talent, instance: instance)
        return created
    }
    
    func update(_ talent: Talent, instance: InstanceProfile) async throws -> Talent {
        let updated: Talent = try await httpClient.request("/api/talent/\(talent.id)", method: .put, query: nil, body: talent, instance: instance)
        return updated
    }
    
    func delete(id: Int, instance: InstanceProfile) async throws {
        try await httpClient.requestVoid("/api/talent/\(id)", method: .delete, query: nil, body: Optional<Talent>.none, instance: instance)
    }
}
