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
    
    enum SaleStatus: String, Codable {
        case pending
        case paid
        case cancelled
        case refunded
        case expired
        
        var displayName: String {
            switch self {
            case .pending: return "Pending"
            case .paid: return "Paid"
            case .cancelled: return "Cancelled"
            case .refunded: return "Refunded"
            case .expired: return "Expired"
            }
        }
        
        var isActive: Bool {
            return self == .paid || self == .pending
        }
    }
    
    struct EventInfo: Codable, Equatable {
        let id: String
        let name: String
        
        enum CodingKeys: String, CodingKey {
            case id, name
        }
        
        // Only decode id and name, ignore all other fields
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(String.self, forKey: .id)
            name = try container.decode(String.self, forKey: .name)
        }
    }
    
    struct SaleTicket: Identifiable, Codable, Equatable {
        let id: Int
        let ticketId: Int
        let quantity: Int
        let usageStatus: String
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
    
    var displayStatus: String {
        status.displayName
    }
    
    var totalQuantity: Int {
        tickets.reduce(0) { $0 + $1.quantity }
    }
}
