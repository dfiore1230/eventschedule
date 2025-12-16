import Foundation

protocol TicketRepositoryProtocol {
    func search(eventId: Int?, query: String?, instance: InstanceProfile) async throws -> [TicketSale]
    func fetch(id: Int, instance: InstanceProfile) async throws -> TicketSale
    func updateStatus(id: Int, action: String, instance: InstanceProfile) async throws -> TicketSale
    func reassign(id: Int, newHolder: String, newEmail: String, instance: InstanceProfile) async throws -> TicketSale
    func addNote(id: Int, note: String, instance: InstanceProfile) async throws
}

final class RemoteTicketRepository: TicketRepositoryProtocol {
    private let httpClient: HTTPClientProtocol
    
    init(httpClient: HTTPClientProtocol) {
        self.httpClient = httpClient
    }
    
    func search(eventId: Int?, query: String?, instance: InstanceProfile) async throws -> [TicketSale] {
        var queryItems: [String: String?] = [:]
        if let eventId = eventId {
            queryItems["event_id"] = String(eventId)
        }
        if let query = query {
            queryItems["query"] = query
        }
        
        do {
            let tickets: [TicketSale] = try await httpClient.request("/api/tickets", method: .get, query: queryItems, body: Optional<TicketSale>.none, instance: instance)
            return tickets
        } catch {
            struct Response: Decodable {
                let data: [TicketSale]
            }
            let response: Response = try await httpClient.request("/api/tickets", method: .get, query: queryItems, body: Optional<TicketSale>.none, instance: instance)
            return response.data
        }
    }
    
    func fetch(id: Int, instance: InstanceProfile) async throws -> TicketSale {
        let response: TicketSale = try await httpClient.request("/api/tickets/\(id)", method: .get, query: nil, body: Optional<TicketSale>.none, instance: instance)
        return response
    }
    
    func updateStatus(id: Int, action: String, instance: InstanceProfile) async throws -> TicketSale {
        struct ActionRequest: Codable {
            let action: String
        }
        
        let request = ActionRequest(action: action)
        
        struct Response: Decodable {
            let data: TicketSale
        }
        
        do {
            let sale: TicketSale = try await httpClient.request("/api/tickets/\(id)", method: .patch, query: nil, body: request, instance: instance)
            return sale
        } catch {
            let response: Response = try await httpClient.request("/api/tickets/\(id)", method: .patch, query: nil, body: request, instance: instance)
            return response.data
        }
    }
    
    func reassign(id: Int, newHolder: String, newEmail: String, instance: InstanceProfile) async throws -> TicketSale {
        struct ReassignRequest: Codable {
            let newHolderName: String
            let newHolderEmail: String
            
            enum CodingKeys: String, CodingKey {
                case newHolderName = "new_holder_name"
                case newHolderEmail = "new_holder_email"
            }
        }
        
        let request = ReassignRequest(newHolderName: newHolder, newHolderEmail: newEmail)
        
        struct Response: Decodable {
            let data: TicketSale
        }
        
        do {
            let sale: TicketSale = try await httpClient.request("/api/tickets/\(id)/reassign", method: .post, query: nil, body: request, instance: instance)
            return sale
        } catch {
            let response: Response = try await httpClient.request("/api/tickets/\(id)/reassign", method: .post, query: nil, body: request, instance: instance)
            return response.data
        }
    }
    
    func addNote(id: Int, note: String, instance: InstanceProfile) async throws {
        struct NoteRequest: Codable {
            let note: String
        }
        
        let request = NoteRequest(note: note)
        try await httpClient.requestVoid("/api/tickets/\(id)/notes", method: .post, query: nil, body: request, instance: instance)
    }
}
