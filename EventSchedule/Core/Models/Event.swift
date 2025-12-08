import Foundation

struct Event: Codable, Identifiable, Equatable {
    let id: String
    var name: String
    var description: String?
    var startAt: Date
    var endAt: Date
    var venueId: String
    var roomId: String?
    var status: EventStatus
    var images: [URL]
    var capacity: Int?
    var ticketTypes: [TicketType]
    var publishState: PublishState
}

enum EventStatus: String, Codable {
    case scheduled
    case ongoing
    case completed
    case cancelled

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        self = EventStatus(rawValue: rawValue) ?? .scheduled
    }
}

enum PublishState: String, Codable {
    case draft
    case published
    case archived

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        self = PublishState(rawValue: rawValue) ?? .draft
    }
}

struct TicketType: Codable, Identifiable, Equatable {
    let id: String
    var name: String
    var price: Decimal?
    var currency: String?

    init(id: String, name: String, price: Decimal? = nil, currency: String? = nil) {
        self.id = id
        self.name = name
        self.price = price
        self.currency = currency
    }
}
