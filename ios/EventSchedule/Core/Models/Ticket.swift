import Foundation

struct Ticket: Identifiable, Codable, Equatable {
    let id: String
    var code: String
    var eventId: String
    var eventName: String?
    var ticketTypeId: String
    var ticketTypeName: String
    var holderName: String?
    var holderEmail: String?
    var status: TicketStatus
    var price: Decimal?
    var currency: String?
    var seat: String?
    var zone: String?
    var purchasedAt: Date?
    var checkedInAt: Date?
    var checkedOutAt: Date?
    var notes: String?
    var history: [HistoryEntry]
    var qrCodeURL: URL?
    
    enum TicketStatus: String, Codable {
        case valid
        case used
        case refunded
        case voided
        case expired
        case transferred
        
        var displayName: String {
            switch self {
            case .valid: return "Valid"
            case .used: return "Used"
            case .refunded: return "Refunded"
            case .voided: return "Voided"
            case .expired: return "Expired"
            case .transferred: return "Transferred"
            }
        }
        
        var isActive: Bool {
            return self == .valid
        }
    }
    
    struct HistoryEntry: Identifiable, Codable, Equatable {
        let id: String
        let action: String
        let performedBy: String?
        let performedAt: Date
        let notes: String?
        
        init(id: String = UUID().uuidString, action: String, performedBy: String? = nil, performedAt: Date = Date(), notes: String? = nil) {
            self.id = id
            self.action = action
            self.performedBy = performedBy
            self.performedAt = performedAt
            self.notes = notes
        }
    }
    
    init(
        id: String,
        code: String,
        eventId: String,
        eventName: String? = nil,
        ticketTypeId: String,
        ticketTypeName: String,
        holderName: String? = nil,
        holderEmail: String? = nil,
        status: TicketStatus = .valid,
        price: Decimal? = nil,
        currency: String? = nil,
        seat: String? = nil,
        zone: String? = nil,
        purchasedAt: Date? = nil,
        checkedInAt: Date? = nil,
        checkedOutAt: Date? = nil,
        notes: String? = nil,
        history: [HistoryEntry] = [],
        qrCodeURL: URL? = nil
    ) {
        self.id = id
        self.code = code
        self.eventId = eventId
        self.eventName = eventName
        self.ticketTypeId = ticketTypeId
        self.ticketTypeName = ticketTypeName
        self.holderName = holderName
        self.holderEmail = holderEmail
        self.status = status
        self.price = price
        self.currency = currency
        self.seat = seat
        self.zone = zone
        self.purchasedAt = purchasedAt
        self.checkedInAt = checkedInAt
        self.checkedOutAt = checkedOutAt
        self.notes = notes
        self.history = history
        self.qrCodeURL = qrCodeURL
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case code
        case eventId = "event_id"
        case eventName = "event_name"
        case ticketTypeId = "ticket_type_id"
        case ticketTypeName = "ticket_type_name"
        case ticketType = "ticket_type"
        case typeName = "type_name"
        case holderName = "holder_name"
        case holderEmail = "holder_email"
        case status
        case price
        case currency
        case seat
        case zone
        case purchasedAt = "purchased_at"
        case checkedInAt = "checked_in_at"
        case checkedOutAt = "checked_out_at"
        case notes
        case history
        case qrCodeURL = "qr_code_url"
        case qrCode = "qr_code"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(String.self, forKey: .id)
        code = try container.decode(String.self, forKey: .code)
        eventId = try container.decode(String.self, forKey: .eventId)
        eventName = try container.decodeIfPresent(String.self, forKey: .eventName)
        ticketTypeId = try container.decode(String.self, forKey: .ticketTypeId)
        
        // Ticket type name can be in multiple fields
        if let typeName = try container.decodeIfPresent(String.self, forKey: .ticketTypeName) {
            ticketTypeName = typeName
        } else if let typeObj = try? container.decode(TicketTypeRef.self, forKey: .ticketType) {
            ticketTypeName = typeObj.name
        } else {
            ticketTypeName = try container.decodeIfPresent(String.self, forKey: .typeName) ?? "General Admission"
        }
        
        holderName = try container.decodeIfPresent(String.self, forKey: .holderName)
        holderEmail = try container.decodeIfPresent(String.self, forKey: .holderEmail)
        status = try container.decodeIfPresent(TicketStatus.self, forKey: .status) ?? .valid
        
        // Price can be numeric or string
        if let numericPrice = try? container.decodeIfPresent(Decimal.self, forKey: .price) {
            price = numericPrice
        } else if let stringPrice = try container.decodeIfPresent(String.self, forKey: .price),
                  let decimalPrice = Decimal(string: stringPrice) {
            price = decimalPrice
        } else {
            price = nil
        }
        
        currency = try container.decodeIfPresent(String.self, forKey: .currency)
        seat = try container.decodeIfPresent(String.self, forKey: .seat)
        zone = try container.decodeIfPresent(String.self, forKey: .zone)
        
        // Dates
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        purchasedAt = try container.decodeIfPresent(Date.self, forKey: .purchasedAt)
        checkedInAt = try container.decodeIfPresent(Date.self, forKey: .checkedInAt)
        checkedOutAt = try container.decodeIfPresent(Date.self, forKey: .checkedOutAt)
        
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        history = try container.decodeIfPresent([HistoryEntry].self, forKey: .history) ?? []
        
        // QR code URL
        if let urlString = try container.decodeIfPresent(String.self, forKey: .qrCodeURL),
           let url = URL(string: urlString) {
            qrCodeURL = url
        } else if let urlString = try container.decodeIfPresent(String.self, forKey: .qrCode),
                  let url = URL(string: urlString) {
            qrCodeURL = url
        } else {
            qrCodeURL = try container.decodeIfPresent(URL.self, forKey: .qrCodeURL)
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(code, forKey: .code)
        try container.encode(eventId, forKey: .eventId)
        try container.encodeIfPresent(eventName, forKey: .eventName)
        try container.encode(ticketTypeId, forKey: .ticketTypeId)
        try container.encode(ticketTypeName, forKey: .ticketTypeName)
        try container.encodeIfPresent(holderName, forKey: .holderName)
        try container.encodeIfPresent(holderEmail, forKey: .holderEmail)
        try container.encode(status, forKey: .status)
        try container.encodeIfPresent(price, forKey: .price)
        try container.encodeIfPresent(currency, forKey: .currency)
        try container.encodeIfPresent(seat, forKey: .seat)
        try container.encodeIfPresent(zone, forKey: .zone)
        try container.encodeIfPresent(purchasedAt, forKey: .purchasedAt)
        try container.encodeIfPresent(checkedInAt, forKey: .checkedInAt)
        try container.encodeIfPresent(checkedOutAt, forKey: .checkedOutAt)
        try container.encodeIfPresent(notes, forKey: .notes)
        try container.encode(history, forKey: .history)
        try container.encodeIfPresent(qrCodeURL, forKey: .qrCodeURL)
    }
    
    var displayStatus: String {
        status.displayName
    }
    
    var canCheckIn: Bool {
        status == .valid && checkedInAt == nil
    }
    
    var canCheckOut: Bool {
        (status == .valid || status == .used) && checkedInAt != nil && checkedOutAt == nil
    }
}

// Helper struct for decoding ticket type references
private struct TicketTypeRef: Decodable {
    let id: String
    let name: String
}
