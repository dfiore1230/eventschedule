import Foundation

struct Event: Codable, Identifiable, Equatable {
    let id: String
    var name: String
    var description: String?
    var startAt: Date
    var endAt: Date
    var durationMinutes: Int?
    var venueId: String
    var venueName: String?
    var roomId: String?
    var status: EventStatus
    var images: [URL]
    var capacity: Int?
    var ticketTypes: [TicketType]
    var publishState: PublishState
    var timezone: String?
    var curatorId: String?
    var talentIds: [String]
    var category: String?
    var groupSlug: String?
    var onlineURL: URL?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case startsAt
        case startAt
        case startTime
        case start
        case endsAt
        case endAt
        case endTime
        case end
        case duration
        case durationMinutes
        case venueId
        case roomId
        case status
        case images
        case capacity
        case ticketTypes
        case publishState
        case timezone
        case tickets
        case venue
        case curatorId
        case curatorRoleId
        case curator
        case curators
        case members
        case talentIds
        case category
        case groupSlug = "group_slug"
        case url
        case onlineUrl = "online_url"
        case eventUrl = "event_url"
    }

    struct VenueReference: Decodable {
        let id: String
        let name: String?
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
            case type
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(String.self, forKey: .id)

            let decodedName = try container.decodeIfPresent(String.self, forKey: .name)
                ?? container.decodeIfPresent(String.self, forKey: .type)
                ?? "Ticket"
            name = decodedName.isEmpty ? "Ticket" : decodedName

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

    struct CategoryPayload: Decodable {
        let id: Int?
        let name: String?
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        venueName = nil

        let decodedTimezone = try container.decodeIfPresent(String.self, forKey: .timezone)
        self.timezone = decodedTimezone
        let tzForParsing = decodedTimezone.flatMap { TimeZone(identifier: $0) }

        if let decodedStart = try Self.decodeDate(
            from: container,
            keys: [.startAt, .startsAt, .startTime, .start],
            timeZone: tzForParsing
        ) {
            startAt = decodedStart
        } else {
            throw DecodingError.keyNotFound(
                CodingKeys.startAt,
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Missing start time")
            )
        }

        if let decodedDuration = try container.decodeIfPresent(Int.self, forKey: .durationMinutes)
            ?? container.decodeIfPresent(Int.self, forKey: .duration) {
            // API provides duration in hours, but the model stores minutes
            durationMinutes = decodedDuration * 60
        } else {
            durationMinutes = nil
        }

        if let explicitEnd = try Self.decodeDate(
            from: container,
            keys: [.endAt, .endsAt, .endTime, .end],
            timeZone: tzForParsing
        ) {
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
        if let categoryString = try? container.decodeIfPresent(String.self, forKey: .category) {
            category = categoryString
        } else if let categoryObject = try? container.decodeIfPresent(CategoryPayload.self, forKey: .category) {
            category = categoryObject.name ?? categoryObject.id.map(String.init)
        } else if let categoryNumber = try? container.decodeIfPresent(Int.self, forKey: .category) {
            category = String(categoryNumber)
        } else {
            category = nil
        }
        groupSlug = try container.decodeIfPresent(String.self, forKey: .groupSlug)

        if let venueIdentifier = try container.decodeIfPresent(String.self, forKey: .venueId) {
            venueId = venueIdentifier
        } else if let venueRef = try container.decodeIfPresent(VenueReference.self, forKey: .venue) {
            venueId = venueRef.id
            venueName = venueRef.name
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

        if let decodedURL = try container.decodeIfPresent(URL.self, forKey: .onlineUrl)
            ?? container.decodeIfPresent(URL.self, forKey: .eventUrl)
            ?? container.decodeIfPresent(URL.self, forKey: .url) {
            onlineURL = decodedURL
        } else if let urlString = try container.decodeIfPresent(String.self, forKey: .onlineUrl)
            ?? container.decodeIfPresent(String.self, forKey: .eventUrl)
            ?? container.decodeIfPresent(String.self, forKey: .url),
                  let parsed = URL(string: urlString) {
            onlineURL = parsed
        } else {
            onlineURL = nil
        }

        // Curator
        if let explicitCuratorId = try container.decodeIfPresent(String.self, forKey: .curatorId) ??
            container.decodeIfPresent(String.self, forKey: .curatorRoleId) {
            curatorId = explicitCuratorId
        } else if let curatorRole = try? container.decodeIfPresent(VenueReference.self, forKey: .curator) {
            curatorId = curatorRole.id
        } else if let curatorRoles = try? container.decodeIfPresent([VenueReference].self, forKey: .curators) {
            curatorId = curatorRoles.first?.id
        } else {
            curatorId = nil
        }

        // Talent
        if let decodedTalentIds = try container.decodeIfPresent([String].self, forKey: .talentIds) {
            talentIds = decodedTalentIds
        } else if let memberDictionary = try? container.decodeIfPresent([String: VenueReference].self, forKey: .members) {
            talentIds = Array(memberDictionary.keys)
        } else if let memberArray = try? container.decodeIfPresent([VenueReference].self, forKey: .members) {
            talentIds = memberArray.map { $0.id }
        } else {
            talentIds = []
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
        venueName: String? = nil,
        roomId: String? = nil,
        status: EventStatus = .scheduled,
        images: [URL] = [],
        capacity: Int? = nil,
        ticketTypes: [TicketType] = [],
        publishState: PublishState = .draft,
        curatorId: String? = nil,
        talentIds: [String] = [],
        category: String? = nil,
        groupSlug: String? = nil,
        onlineURL: URL? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.startAt = startAt
        self.endAt = endAt
        self.durationMinutes = durationMinutes
        self.venueId = venueId
        self.venueName = venueName
        self.roomId = roomId
        self.status = status
        self.images = images
        self.capacity = capacity
        self.ticketTypes = ticketTypes
        self.publishState = publishState
        self.timezone = nil
        self.curatorId = curatorId
        self.talentIds = talentIds
        self.category = category
        self.groupSlug = groupSlug
        self.onlineURL = onlineURL
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(description, forKey: .description)
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)

        try container.encode(formatter.string(from: startAt), forKey: .startsAt)
        try container.encode(formatter.string(from: endAt), forKey: .endAt)
        // API expects duration in hours
        if let durationMinutes, durationMinutes > 0 {
            try container.encode(durationMinutes / 60, forKey: .durationMinutes)
        }
        try container.encode(venueId, forKey: .venueId)
        try container.encodeIfPresent(roomId, forKey: .roomId)
        try container.encode(status, forKey: .status)
        try container.encode(images, forKey: .images)
        try container.encodeIfPresent(capacity, forKey: .capacity)
        try container.encode(ticketTypes, forKey: .ticketTypes)
        try container.encode(publishState, forKey: .publishState)
        try container.encodeIfPresent(curatorId, forKey: .curatorRoleId)
        try container.encodeIfPresent(category, forKey: .category)
        try container.encodeIfPresent(groupSlug, forKey: .groupSlug)
        try container.encodeIfPresent(onlineURL, forKey: .url)
        if !talentIds.isEmpty {
            try container.encode(talentIds, forKey: .members)
        }
    }

    var venueDisplayDescription: String {
        if let venueName, !venueName.isEmpty {
            return venueName
        }
        if venueId.isEmpty {
            return "Unknown venue"
        }
        return venueId
    }

    private static let iso8601WithFractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let iso8601: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private static let fallbackDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()

    private static let fallbackDateFormatterWithSpace: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()

    static func payloadDateFormatter(timeZone: TimeZone = .current) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }

    private static func decodeDate(
        from container: KeyedDecodingContainer<CodingKeys>,
        keys: [CodingKeys],
        timeZone: TimeZone?
    ) throws -> Date? {
        for key in keys {
            if let decodedDate = try? container.decodeIfPresent(Date.self, forKey: key) {
                return decodedDate
            }

            if let timestamp = try? container.decodeIfPresent(Double.self, forKey: key) {
                // Assume seconds since epoch
                return Date(timeIntervalSince1970: timestamp)
            }

            if let intTimestamp = try? container.decodeIfPresent(Int.self, forKey: key) {
                // Detect milliseconds and convert to seconds
                let timeInterval: TimeInterval = intTimestamp > 1_000_000_000_000
                    ? TimeInterval(intTimestamp) / 1000
                    : TimeInterval(intTimestamp)
                return Date(timeIntervalSince1970: timeInterval)
            }

            if let dateString = try? container.decodeIfPresent(String.self, forKey: key) {
                if let parsed = iso8601WithFractional.date(from: dateString) {
                    return parsed
                }
                if let parsed = iso8601.date(from: dateString) {
                    return parsed
                }
                if let parsed = fallbackDateFormatter.date(from: dateString) {
                    return parsed
                }
                let spaceFormatter = DateFormatter()
                spaceFormatter.locale = Locale(identifier: "en_US_POSIX")
                spaceFormatter.calendar = Calendar(identifier: .gregorian)
                spaceFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                spaceFormatter.timeZone = timeZone ?? TimeZone(secondsFromGMT: 0)
                if let parsed = spaceFormatter.date(from: dateString) {
                    return parsed
                }
            }
        }

        return nil
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

extension Event {
    func displayTimeZone(fallback: TimeZone? = nil) -> TimeZone {
        if let timezone, let zone = TimeZone(identifier: timezone) {
            return zone
        }
        if let fallback {
            return fallback
        }
        return .current
    }

    func formattedDateTime(_ date: Date, fallbackTimeZone: TimeZone? = nil) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = displayTimeZone(fallback: fallbackTimeZone)
        // Matches: abbreviated month, day, year, hour and minute (e.g., "Jan 3, 2025 at 5:42 PM")
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

