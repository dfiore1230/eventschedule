import Foundation

protocol TicketRepositoryProtocol {
    func search(eventId: String?, query: String?, instance: InstanceProfile) async throws -> [Ticket]
    func fetch(id: String, instance: InstanceProfile) async throws -> Ticket
    func issue(_ ticket: Ticket, instance: InstanceProfile) async throws -> Ticket
    func refund(id: String, instance: InstanceProfile) async throws -> Ticket
    func void(id: String, instance: InstanceProfile) async throws -> Ticket
    func reassign(id: String, newHolder: String, newEmail: String, instance: InstanceProfile) async throws -> Ticket
    func addNote(id: String, note: String, instance: InstanceProfile) async throws -> Ticket
}

final class RemoteTicketRepository: TicketRepositoryProtocol {
    private let httpClient: HTTPClientProtocol
    
    init(httpClient: HTTPClientProtocol) {
        self.httpClient = httpClient
    }
    
    func search(eventId: String?, query: String?, instance: InstanceProfile) async throws -> [Ticket] {
        let queryItems: [String: String?] = [
            "event_id": eventId,
            "query": query
        ]
        
        do {
            let tickets: [Ticket] = try await httpClient.request("api/tickets", method: .get, query: queryItems, body: Optional<Ticket>.none, instance: instance)
            return tickets
        } catch {
            struct Response: Decodable {
                let data: [Ticket]
            }
            let response: Response = try await httpClient.request("api/tickets", method: .get, query: queryItems, body: Optional<Ticket>.none, instance: instance)
            return response.data
        }
    }
    
    func fetch(id: String, instance: InstanceProfile) async throws -> Ticket {
        let response: Ticket = try await httpClient.request("api/tickets/\(id)", method: .get, query: nil, body: Optional<Ticket>.none, instance: instance)
        return response
    }
    
    func issue(_ ticket: Ticket, instance: InstanceProfile) async throws -> Ticket {
        let created: Ticket = try await httpClient.request("api/tickets", method: .post, query: nil, body: ticket, instance: instance)
        return created
    }
    
    func refund(id: String, instance: InstanceProfile) async throws -> Ticket {
        let ticket: Ticket = try await httpClient.request("api/tickets/\(id)/refund", method: .post, query: nil, body: Optional<Ticket>.none, instance: instance)
        return ticket
    }
    
    func void(id: String, instance: InstanceProfile) async throws -> Ticket {
        let ticket: Ticket = try await httpClient.request("api/tickets/\(id)/void", method: .post, query: nil, body: Optional<Ticket>.none, instance: instance)
        return ticket
    }
    
    func reassign(id: String, newHolder: String, newEmail: String, instance: InstanceProfile) async throws -> Ticket {
        struct ReassignRequest: Codable {
            let holderName: String
            let holderEmail: String
            
            enum CodingKeys: String, CodingKey {
                case holderName = "holder_name"
                case holderEmail = "holder_email"
            }
        }
        
        let request = ReassignRequest(holderName: newHolder, holderEmail: newEmail)
        let ticket: Ticket = try await httpClient.request("api/tickets/\(id)/reassign", method: .post, query: nil, body: request, instance: instance)
        return ticket
    }
    
    func addNote(id: String, note: String, instance: InstanceProfile) async throws -> Ticket {
        struct NoteRequest: Codable {
            let note: String
        }
        
        let request = NoteRequest(note: note)
        let ticket: Ticket = try await httpClient.request("api/tickets/\(id)/notes", method: .post, query: nil, body: request, instance: instance)
        return ticket
    }
}
