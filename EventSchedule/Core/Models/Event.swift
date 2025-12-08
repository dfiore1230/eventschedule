import Foundation

struct Event: Codable, Identifiable, Equatable {
    let id: String
    var name: String
    var description: String?
    var startAt: Date
    var endAt: Date
    var durationMinutes: Int?
    var venueId: String
    var roomId: String?
    var status: EventStatus
    var images: [URL]
    var capacity: Int?
    var ticketTypes: [TicketType]
    var publishState: PublishState

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case startsAt
        case startAt
        case endsAt
        case endAt
        case duration
        case durationMinutes
        case venueId
        case roomId
        case status
        case images
        case capacity
        case ticketTypes
        case publishState
        case tickets
        case venue
    }

    struct VenueReference: Decodable {
        let id: String
    }

    struct TicketPayload: Decodable {
        let id: String
        let name: String
        let price: Decimal?
        let currency: String?

        private enum CodingKeys: String, CodingKey {
            case id
            case name
            case price
            case currency
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(String.self, forKey: .id)
            name = try container.decode(String.self, forKey: .name)
            currency = try container.decodeIfPresent(String.self, forKey: .currency)

            if let numericPrice = try? container.decodeIfPresent(Decimal.self, forKey: .price) {
                price = numericPrice
            } else if let stringPrice = try container.decodeIfPresent(String.self, forKey: .price),
                      let decimalPrice = Decimal(string: stringPrice) {
                price = decimalPrice
            } else {
                price = nil
            }
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        if let explicitStart = try container.decodeIfPresent(Date.self, forKey: .startAt) {
            startAt = explicitStart
        } else if let alternateStart = try container.decodeIfPresent(Date.self, forKey: .startsAt) {
            startAt = alternateStart
        } else {
            throw DecodingError.keyNotFound(
                CodingKeys.startAt,
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Missing start time")
            )
        }

        let decodedDuration = try container.decodeIfPresent(Int.self, forKey: .durationMinutes)
            ?? container.decodeIfPresent(Int.self, forKey: .duration)
        durationMinutes = decodedDuration

        if let explicitEnd = try container.decodeIfPresent(Date.self, forKey: .endAt) ??
            container.decodeIfPresent(Date.self, forKey: .endsAt) {
            endAt = explicitEnd
        } else if let durationMinutes, durationMinutes > 0 {
            endAt = startAt.addingTimeInterval(TimeInterval(durationMinutes * 60))
        } else {
            endAt = startAt.addingTimeInterval(3600)
        }
        roomId = try container.decodeIfPresent(String.self, forKey: .roomId)
        status = try container.decodeIfPresent(EventStatus.self, forKey: .status) ?? .scheduled
        images = try container.decodeIfPresent([URL].self, forKey: .images) ?? []
        capacity = try container.decodeIfPresent(Int.self, forKey: .capacity)
        publishState = try container.decodeIfPresent(PublishState.self, forKey: .publishState) ?? .draft

        if let venueIdentifier = try container.decodeIfPresent(String.self, forKey: .venueId) {
            venueId = venueIdentifier
        } else if let venueRef = try container.decodeIfPresent(VenueReference.self, forKey: .venue) {
            venueId = venueRef.id
        } else {
            venueId = "Unknown venue"
        }

        if let decodedTicketTypes = try container.decodeIfPresent([TicketType].self, forKey: .ticketTypes) {
            ticketTypes = decodedTicketTypes
        } else if let ticketPayloads = try container.decodeIfPresent([TicketPayload].self, forKey: .tickets) {
            ticketTypes = ticketPayloads.map { TicketType(id: $0.id, name: $0.name, price: $0.price, currency: $0.currency) }
        } else {
            ticketTypes = []
        }
    }

    init(
        id: String,
        name: String,
        description: String? = nil,
        startAt: Date,
        endAt: Date,
        durationMinutes: Int? = nil,
        venueId: String,
        roomId: String? = nil,
        status: EventStatus = .scheduled,
        images: [URL] = [],
        capacity: Int? = nil,
        ticketTypes: [TicketType] = [],
        publishState: PublishState = .draft
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.startAt = startAt
        self.endAt = endAt
        self.durationMinutes = durationMinutes
        self.venueId = venueId
        self.roomId = roomId
        self.status = status
        self.images = images
        self.capacity = capacity
        self.ticketTypes = ticketTypes
        self.publishState = publishState
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encode(startAt, forKey: .startsAt)
        try container.encode(endAt, forKey: .endAt)
        try container.encodeIfPresent(durationMinutes, forKey: .durationMinutes)
        try container.encode(venueId, forKey: .venueId)
        try container.encodeIfPresent(roomId, forKey: .roomId)
        try container.encode(status, forKey: .status)
        try container.encode(images, forKey: .images)
        try container.encodeIfPresent(capacity, forKey: .capacity)
        try container.encode(ticketTypes, forKey: .ticketTypes)
        try container.encode(publishState, forKey: .publishState)
    }
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
