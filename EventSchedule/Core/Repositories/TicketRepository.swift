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
        var components = URLComponents(url: instance.baseURL.appendingPathComponent("/api/tickets"), resolvingAgainstBaseURL: false)!
        
        var queryItems: [URLQueryItem] = []
        if let eventId = eventId {
            queryItems.append(URLQueryItem(name: "event_id", value: eventId))
        }
        if let query = query {
            queryItems.append(URLQueryItem(name: "query", value: query))
        }
        
        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }
        
        let data = try await httpClient.get(url: components.url!, instance: instance)
        
        // Try to decode as array directly first
        if let tickets = try? JSONDecoder.iso8601.decode([Ticket].self, from: data) {
            return tickets
        }
        
        // Try to decode as wrapped response with 'data' key
        struct Response: Decodable {
            let data: [Ticket]
        }
        
        let response = try JSONDecoder.iso8601.decode(Response.self, from: data)
        return response.data
    }
    
    func fetch(id: String, instance: InstanceProfile) async throws -> Ticket {
        let url = instance.baseURL.appendingPathComponent("/api/tickets/\(id)")
        let data = try await httpClient.get(url: url, instance: instance)
        return try JSONDecoder.iso8601.decode(Ticket.self, from: data)
    }
    
    func issue(_ ticket: Ticket, instance: InstanceProfile) async throws -> Ticket {
        let url = instance.baseURL.appendingPathComponent("/api/tickets")
        let body = try JSONEncoder.iso8601.encode(ticket)
        let data = try await httpClient.post(url: url, body: body, instance: instance)
        return try JSONDecoder.iso8601.decode(Ticket.self, from: data)
    }
    
    func refund(id: String, instance: InstanceProfile) async throws -> Ticket {
        let url = instance.baseURL.appendingPathComponent("/api/tickets/\(id)/refund")
        let data = try await httpClient.post(url: url, body: Data(), instance: instance)
        return try JSONDecoder.iso8601.decode(Ticket.self, from: data)
    }
    
    func void(id: String, instance: InstanceProfile) async throws -> Ticket {
        let url = instance.baseURL.appendingPathComponent("/api/tickets/\(id)/void")
        let data = try await httpClient.post(url: url, body: Data(), instance: instance)
        return try JSONDecoder.iso8601.decode(Ticket.self, from: data)
    }
    
    func reassign(id: String, newHolder: String, newEmail: String, instance: InstanceProfile) async throws -> Ticket {
        let url = instance.baseURL.appendingPathComponent("/api/tickets/\(id)/reassign")
        
        struct ReassignRequest: Codable {
            let holderName: String
            let holderEmail: String
            
            enum CodingKeys: String, CodingKey {
                case holderName = "holder_name"
                case holderEmail = "holder_email"
            }
        }
        
        let request = ReassignRequest(holderName: newHolder, holderEmail: newEmail)
        let body = try JSONEncoder.iso8601.encode(request)
        let data = try await httpClient.post(url: url, body: body, instance: instance)
        return try JSONDecoder.iso8601.decode(Ticket.self, from: data)
    }
    
    func addNote(id: String, note: String, instance: InstanceProfile) async throws -> Ticket {
        let url = instance.baseURL.appendingPathComponent("/api/tickets/\(id)/notes")
        
        struct NoteRequest: Codable {
            let note: String
        }
        
        let request = NoteRequest(note: note)
        let body = try JSONEncoder.iso8601.encode(request)
        let data = try await httpClient.post(url: url, body: body, instance: instance)
        return try JSONDecoder.iso8601.decode(Ticket.self, from: data)
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
