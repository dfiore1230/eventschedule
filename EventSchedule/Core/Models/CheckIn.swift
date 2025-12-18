import Foundation

/// Represents a check-in or check-out action for a ticket
struct CheckIn: Identifiable, Codable, Equatable {
    let id: String
    let ticketId: String
    let ticketCode: String?
    let eventId: String
    let attendeeName: String?
    let gateId: String?
    let deviceId: String?
    let action: CheckInAction
    let timestamp: Date
    let performedBy: String?
    let notes: String?
    let isOffline: Bool
    let syncedAt: Date?
    
    enum CheckInAction: String, Codable {
        case checkIn = "checkin"
        case checkOut = "checkout"
        
        var displayName: String {
            switch self {
            case .checkIn: return "Check In"
            case .checkOut: return "Check Out"
            }
        }
    }
    
    init(
        id: String = UUID().uuidString,
        ticketId: String,
        ticketCode: String? = nil,
        eventId: String,
        attendeeName: String? = nil,
        gateId: String? = nil,
        deviceId: String? = nil,
        action: CheckInAction,
        timestamp: Date = Date(),
        performedBy: String? = nil,
        notes: String? = nil,
        isOffline: Bool = false,
        syncedAt: Date? = nil
    ) {
        self.id = id
        self.ticketId = ticketId
        self.ticketCode = ticketCode
        self.eventId = eventId
        self.attendeeName = attendeeName
        self.gateId = gateId
        self.deviceId = deviceId
        self.action = action
        self.timestamp = timestamp
        self.performedBy = performedBy
        self.notes = notes
        self.isOffline = isOffline
        self.syncedAt = syncedAt
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case ticketId = "ticket_id"
        case ticketCode = "ticket_code"
        case code
        case eventId = "event_id"
        case gateId = "gate_id"
        case deviceId = "device_id"
        case action
        case timestamp
        case ts
        case performedBy = "performed_by"
        case notes
        case isOffline = "is_offline"
        case syncedAt = "synced_at"
        case attendeeName = "attendee_name"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
            id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
            ticketId = try container.decodeIfPresent(String.self, forKey: .ticketId) ?? ""
            ticketCode = try container.decodeIfPresent(String.self, forKey: .ticketCode)
                ?? container.decodeIfPresent(String.self, forKey: .code)
            eventId = try container.decodeIfPresent(String.self, forKey: .eventId) ?? ""
            attendeeName = try container.decodeIfPresent(String.self, forKey: .attendeeName)
            gateId = try container.decodeIfPresent(String.self, forKey: .gateId)
            deviceId = try container.decodeIfPresent(String.self, forKey: .deviceId)
            action = try container.decodeIfPresent(CheckInAction.self, forKey: .action) ?? .checkIn

            if let ts = try container.decodeIfPresent(Date.self, forKey: .timestamp) {
                timestamp = ts
            } else {
                timestamp = try container.decodeIfPresent(Date.self, forKey: .ts) ?? Date()
            }

            performedBy = try container.decodeIfPresent(String.self, forKey: .performedBy)
            notes = try container.decodeIfPresent(String.self, forKey: .notes)
            isOffline = try container.decodeIfPresent(Bool.self, forKey: .isOffline) ?? false
            syncedAt = try container.decodeIfPresent(Date.self, forKey: .syncedAt)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(ticketId, forKey: .ticketId)
        try container.encodeIfPresent(ticketCode, forKey: .ticketCode)
        try container.encode(eventId, forKey: .eventId)
        try container.encodeIfPresent(gateId, forKey: .gateId)
        try container.encodeIfPresent(deviceId, forKey: .deviceId)
        try container.encode(action, forKey: .action)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encodeIfPresent(performedBy, forKey: .performedBy)
        try container.encodeIfPresent(notes, forKey: .notes)
        try container.encode(isOffline, forKey: .isOffline)
        try container.encodeIfPresent(syncedAt, forKey: .syncedAt)
        try container.encodeIfPresent(attendeeName, forKey: .attendeeName)
    }
    
    /// Generate an idempotency key for this check-in to prevent duplicates
    func idempotencyKey() -> String {
        let devicePart = deviceId ?? "unknown"
        let epochSecond = Int(timestamp.timeIntervalSince1970)
        return "\(devicePart):\(ticketId):\(epochSecond)"
    }
}

/// Result of a scan/check-in operation
struct ScanResult: Codable, Equatable {
    enum Status: String, Codable {
        case admitted
        case alreadyUsed = "already_used"
        case refunded
        case voided
        case wrongEvent = "wrong_event"
        case wrongDate = "wrong_date"
        case unpaid
        case cancelled
        case unknown
        case expired
        case invalid
        
        var displayName: String {
            switch self {
            case .admitted: return "Admitted"
            case .alreadyUsed: return "Already Used"
            case .refunded: return "Refunded"
            case .voided: return "Voided"
            case .wrongEvent: return "Wrong Event"
            case .wrongDate: return "Wrong Date"
            case .unpaid: return "Unpaid"
            case .cancelled: return "Cancelled"
            case .unknown: return "Unknown"
            case .expired: return "Expired"
            case .invalid: return "Invalid"
        }
        }
        
        var isSuccess: Bool {
            return self == .admitted
        }
    }
    
    let status: Status
    let ticketId: String?
    let holder: String?
    let eventId: String?
    let eventName: String?
    let checkedInAt: Date?
    let gateId: String?
    let serverTime: Date
    let message: String?
    let saleTicketId: Int?
    
    init(
        status: Status,
        ticketId: String? = nil,
        holder: String? = nil,
        eventId: String? = nil,
        eventName: String? = nil,
        checkedInAt: Date? = nil,
        gateId: String? = nil,
        serverTime: Date = Date(),
        message: String? = nil,
        saleTicketId: Int? = nil
    ) {
        self.status = status
        self.ticketId = ticketId
        self.holder = holder
        self.eventId = eventId
        self.eventName = eventName
        self.checkedInAt = checkedInAt
        self.gateId = gateId
        self.serverTime = serverTime
        self.message = message
        self.saleTicketId = saleTicketId
    }
    
    enum CodingKeys: String, CodingKey {
        case status
        case ticketId = "ticket_id"
        case holder
        case holderName = "holder_name"
        case eventId = "event_id"
        case eventName = "event_name"
        case checkedInAt = "checked_in_at"
        case gateId = "gate_id"
        case serverTime = "server_time"
        case message
        case saleTicketId = "sale_ticket_id"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        status = try container.decode(Status.self, forKey: .status)
        ticketId = try container.decodeIfPresent(String.self, forKey: .ticketId)
        
        // Holder can be in 'holder' or 'holder_name' field
        if let holderDecode = try container.decodeIfPresent(String.self, forKey: .holder) {
            holder = holderDecode
        } else {
            holder = try container.decodeIfPresent(String.self, forKey: .holderName)
        }
        
        eventId = try container.decodeIfPresent(String.self, forKey: .eventId)
        eventName = try container.decodeIfPresent(String.self, forKey: .eventName)
        checkedInAt = try container.decodeIfPresent(Date.self, forKey: .checkedInAt)
        gateId = try container.decodeIfPresent(String.self, forKey: .gateId)
        serverTime = try container.decodeIfPresent(Date.self, forKey: .serverTime) ?? Date()
        message = try container.decodeIfPresent(String.self, forKey: .message)
        saleTicketId = try container.decodeIfPresent(Int.self, forKey: .saleTicketId)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(status, forKey: .status)
        try container.encodeIfPresent(ticketId, forKey: .ticketId)
        try container.encodeIfPresent(holder, forKey: .holder)
        try container.encodeIfPresent(eventId, forKey: .eventId)
        try container.encodeIfPresent(eventName, forKey: .eventName)
        try container.encodeIfPresent(checkedInAt, forKey: .checkedInAt)
        try container.encodeIfPresent(gateId, forKey: .gateId)
        try container.encode(serverTime, forKey: .serverTime)
        try container.encodeIfPresent(message, forKey: .message)
        try container.encodeIfPresent(saleTicketId, forKey: .saleTicketId)
    }
}
