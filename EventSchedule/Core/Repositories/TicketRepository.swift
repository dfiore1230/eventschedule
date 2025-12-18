import Foundation

struct TicketPagination: Decodable, Equatable {
    let currentPage: Int
    let lastPage: Int
    let perPage: Int
    let total: Int

    enum CodingKeys: String, CodingKey {
        case currentPage = "current_page"
        case lastPage = "last_page"
        case perPage = "per_page"
        case total
    }
}

protocol TicketRepositoryProtocol {
    func search(eventId: Int?, query: String?, instance: InstanceProfile) async throws -> [TicketSale]
    func searchPage(eventId: Int?, query: String?, page: Int?, perPage: Int?, instance: InstanceProfile) async throws -> ([TicketSale], TicketPagination?)
    func fetch(id: Int, instance: InstanceProfile) async throws -> TicketSale
    func updateStatus(id: Int, action: String, instance: InstanceProfile) async throws -> TicketSale
    func markAsPaid(id: Int, instance: InstanceProfile) async throws -> TicketSale
    func markAsUnpaid(id: Int, instance: InstanceProfile) async throws -> TicketSale
    func refund(id: Int, instance: InstanceProfile) async throws -> TicketSale
    func cancel(id: Int, instance: InstanceProfile) async throws -> TicketSale
    func markAsUsed(id: Int, instance: InstanceProfile) async throws -> TicketSale
    func markAsUnused(id: Int, instance: InstanceProfile) async throws -> TicketSale
    func delete(id: Int, instance: InstanceProfile) async throws -> TicketSale
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
        
        let (data, _) = try await searchPage(eventId: eventId, query: query, page: nil, perPage: nil, instance: instance)
        return data
    }

    func searchPage(eventId: Int?, query: String?, page: Int?, perPage: Int?, instance: InstanceProfile) async throws -> ([TicketSale], TicketPagination?) {
        var queryItems: [String: String?] = [:]
        if let eventId = eventId { queryItems["event_id"] = String(eventId) }
        if let query = query, !query.isEmpty { queryItems["query"] = query }
        if let page = page { queryItems["page"] = String(page) }
        if let perPage = perPage { queryItems["per_page"] = String(perPage) }
        // Cache-busting: append timestamp to force fresh data from backend
        queryItems["_t"] = String(Int(Date().timeIntervalSince1970))

        struct PaginatedResponse: Decodable {
            let data: [TicketSale]
            let meta: TicketPagination?

            private enum CodingKeys: String, CodingKey { case data, meta }

            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                // Decode data array defensively
                let decodedData = (try? container.decode([TicketSale].self, forKey: .data)) ?? []
                self.data = decodedData
                // Decode meta defensively; tolerate shape mismatches
                self.meta = try? container.decode(TicketPagination.self, forKey: .meta)
            }
        }

        let response: PaginatedResponse = try await httpClient.request(
            "/api/tickets",
            method: .get,
            query: queryItems,
            body: Optional<TicketSale>.none,
            instance: instance
        )

        // Diagnostics: log ticket usage_status presence to validate backend shape
        for sale in response.data {
            let count = sale.tickets.count
            if count == 0 {
                DebugLogger.log("TicketSale #\(sale.id): tickets array is EMPTY in response")
            } else {
                let details = sale.tickets.map { "id:\($0.id) ticket_id:\($0.ticketId) qty:\($0.quantity) status:\($0.usageStatus)" }.joined(separator: " | ")
                DebugLogger.log("TicketSale #\(sale.id): tickets=\(count) details=[\(details)]")
            }
        }

        return (response.data, response.meta)
    }
    
    func fetch(id: Int, instance: InstanceProfile) async throws -> TicketSale {
        let response: TicketSale = try await httpClient.request("/api/tickets/\(id)", method: .get, query: nil, body: Optional<TicketSale>.none, instance: instance)
        return response
    }
    
    func updateStatus(id: Int, action: String, instance: InstanceProfile) async throws -> TicketSale {
        struct ActionRequest: Codable {
            let action: String
        }
        
        struct MinimalTicketResponse: Decodable {
            let data: MinimalTicket
        }
        
        struct MinimalTicket: Decodable {
            let id: Int
            let status: String
        }
        
        let request = ActionRequest(action: action)
        
        // The cancel/approve/etc actions return a minimal response with just id and status
        // The server doesn't support GET /api/tickets/{id}, so we can't fetch full details
        // Just decode the minimal response and create a placeholder ticket with updated status
        let response: MinimalTicketResponse = try await httpClient.request("/api/tickets/\(id)", method: .patch, query: nil, body: request, instance: instance)
        
        // Parse the status from the response
        let statusString = response.data.status
        let status = TicketSale.SaleStatus(rawValue: statusString) ?? .pending
        
        // Return a minimal ticket with the updated status
        // The UI should refresh the list to get full details
        return TicketSale(
            id: id,
            status: status,
            name: "",
            email: "",
            eventId: 0,
            event: nil,
            tickets: []
        )
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
    
    func markAsPaid(id: Int, instance: InstanceProfile) async throws -> TicketSale {
        return try await updateStatus(id: id, action: "mark_paid", instance: instance)
    }
    
    func markAsUnpaid(id: Int, instance: InstanceProfile) async throws -> TicketSale {
        return try await updateStatus(id: id, action: "mark_unpaid", instance: instance)
    }
    
    func refund(id: Int, instance: InstanceProfile) async throws -> TicketSale {
        return try await updateStatus(id: id, action: "refund", instance: instance)
    }
    
    func cancel(id: Int, instance: InstanceProfile) async throws -> TicketSale {
        return try await updateStatus(id: id, action: "cancel", instance: instance)
    }
    
    func markAsUsed(id: Int, instance: InstanceProfile) async throws -> TicketSale {
        return try await updateStatus(id: id, action: "mark_used", instance: instance)
    }
    
    func markAsUnused(id: Int, instance: InstanceProfile) async throws -> TicketSale {
        return try await updateStatus(id: id, action: "mark_unused", instance: instance)
    }
    
    func delete(id: Int, instance: InstanceProfile) async throws -> TicketSale {
        return try await updateStatus(id: id, action: "delete", instance: instance)
    }
    
    func addNote(id: Int, note: String, instance: InstanceProfile) async throws {
        struct NoteRequest: Codable {
            let note: String
        }
        
        let request = NoteRequest(note: note)
        try await httpClient.requestVoid("/api/tickets/\(id)/notes", method: .post, query: nil, body: request, instance: instance)
    }
}
