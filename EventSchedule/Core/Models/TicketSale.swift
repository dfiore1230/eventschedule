import Foundation

/// Represents a ticket sale transaction from the API
struct TicketSale: Identifiable, Codable, Equatable {
    let id: Int
    var status: SaleStatus
    var name: String
    var email: String
    var eventId: Int
    var event: EventInfo?
    var tickets: [SaleTicket]
    
    enum CodingKeys: String, CodingKey {
        case id
        case status
        case name
        case email
        case eventId = "event_id"
        case event
        case tickets
    }
    
    enum SaleStatus: String, Codable {
        case pending
        case paid
        case unpaid
        case cancelled
        case refunded
        case expired
        case deleted
        
        var displayName: String {
            switch self {
            case .pending: return "Pending"
            case .paid: return "Paid"
            case .unpaid: return "Unpaid"
            case .cancelled: return "Cancelled"
            case .refunded: return "Refunded"
            case .expired: return "Expired"
            case .deleted: return "Deleted"
            }
        }
        
        var isActive: Bool {
            return self == .paid || self == .pending || self == .unpaid
        }
    }
    
    struct EventInfo: Codable, Equatable {
        let id: String
        let name: String

        init(id: String = "", name: String = "") {
            self.id = id
            self.name = name
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let id = try container.decodeIfPresent(String.self, forKey: .id) ?? ""
            let name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
            self.init(id: id, name: name)
        }

        private enum CodingKeys: String, CodingKey {
            case id
            case name
        }
    }
    
    struct SaleTicket: Identifiable, Codable, Equatable {
        let id: Int
        let ticketId: Int
        let quantity: Int
        let usageStatus: String

        init(id: Int = 0, ticketId: Int = 0, quantity: Int = 0, usageStatus: String = "unused") {
            self.id = id
            self.ticketId = ticketId
            self.quantity = quantity
            self.usageStatus = usageStatus
        }
    }
    
    init(
        id: Int,
        status: SaleStatus,
        name: String,
        email: String,
        eventId: Int,
        event: EventInfo? = nil,
        tickets: [SaleTicket] = []
    ) {
        self.id = id
        self.status = status
        self.name = name
        self.email = email
        self.eventId = eventId
        self.event = event
        self.tickets = tickets
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decodeIfPresent(Int.self, forKey: .id) ?? 0
        let status = try container.decodeIfPresent(SaleStatus.self, forKey: .status) ?? .pending
        let name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        let email = try container.decodeIfPresent(String.self, forKey: .email) ?? ""
        let eventId = try container.decodeIfPresent(Int.self, forKey: .eventId) ?? 0
        let event = try container.decodeIfPresent(EventInfo.self, forKey: .event)
        let tickets = try container.decodeIfPresent([SaleTicket].self, forKey: .tickets) ?? []
        self.init(id: id, status: status, name: name, email: email, eventId: eventId, event: event, tickets: tickets)
    }
    
    var displayStatus: String {
        status.displayName
    }
    
    var totalQuantity: Int {
        tickets.reduce(0) { $0 + $1.quantity }
    }
}
