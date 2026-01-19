import Foundation

struct Event: Codable, Identifiable, Equatable {
    let id: String
    var name: String
    var description: String?
    var startAt: Date
    var endAt: Date
    var durationMinutes: Int?
    var venueId: String?
    var venueName: String?
    var roomId: String?
    var images: [URL]
    var flyerImageUrl: String?
    var flyerImageId: String?
    var capacity: Int?
    var ticketTypes: [TicketType]
    var publishState: PublishState
    var timezone: String?
    var curatorId: String?
    var talentIds: [String]
    var category: String?
    var groupSlug: String?
    var onlineURL: URL?
    var isRecurring: Bool?
    var attendeesVisible: Bool?

    // Raw fields captured from server payload for precise wall-time comparison
    var rawStartsAtString: String?
    var rawEndsAtString: String?
    var rawTimezoneIdentifier: String?

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
        case images
        case flyerImageUrl
        case flyerImageId
        case capacity
        case ticketTypes
        case publishState
        case timezone
        case tickets
        case venue
        case curatorId
        case curatorIdAlt = "curator_id"
        case curatorRoleId
        case curator
        case curators
        case members
        case talentIds
        case talentIdsAlt = "talent_ids"
        case memberRoleIds = "member_role_ids"
        case category
        case groupSlug = "group_slug"
        case url
        case onlineUrl = "online_url"
        case eventUrl = "event_url"
        case isRecurring = "is_recurring"
        case attendeesVisible = "attendees_visible"
        case rawStartsAtString = "starts_at"
        case rawEndsAtString = "ends_at"
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
        let quantity: Int?

        private enum CodingKeys: String, CodingKey {
            case id
            case name
            case price
            case currency
            case type
            case quantity
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

            quantity = try container.decodeIfPresent(Int.self, forKey: .quantity)
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

        // Capture raw server fields for wall-time comparison
        let rawStarts = try container.decodeIfPresent(String.self, forKey: .rawStartsAtString)
        let rawEnds = try container.decodeIfPresent(String.self, forKey: .rawEndsAtString)
        self.rawStartsAtString = rawStarts
        self.rawEndsAtString = rawEnds

        let decodedTimezone = try container.decodeIfPresent(String.self, forKey: .timezone)
        self.timezone = decodedTimezone
        self.rawTimezoneIdentifier = decodedTimezone
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
        images = try container.decodeIfPresent([URL].self, forKey: .images) ?? []
        flyerImageUrl = try container.decodeIfPresent(String.self, forKey: .flyerImageUrl)
        flyerImageId = try container.decodeIfPresent(String.self, forKey: .flyerImageId)
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
            venueId = venueIdentifier.isEmpty ? nil : venueIdentifier
        } else if let venueRef = try container.decodeIfPresent(VenueReference.self, forKey: .venue) {
            venueId = venueRef.id
            venueName = venueRef.name
        } else {
            venueId = nil
        }

        if let decodedTicketTypes = try container.decodeIfPresent([TicketType].self, forKey: .ticketTypes) {
            ticketTypes = decodedTicketTypes
        } else if let ticketPayloads = try container.decodeIfPresent([TicketPayload].self, forKey: .tickets) {
            ticketTypes = ticketPayloads.map { TicketType(id: $0.id, name: $0.name, price: $0.price, currency: $0.currency, quantity: $0.quantity) }
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

        isRecurring = try container.decodeIfPresent(Bool.self, forKey: .isRecurring)
        attendeesVisible = try container.decodeIfPresent(Bool.self, forKey: .attendeesVisible)

        // Curator
        if let explicitCuratorId = try container.decodeIfPresent(String.self, forKey: .curatorId) ??
            container.decodeIfPresent(String.self, forKey: .curatorRoleId) {
            curatorId = explicitCuratorId
        } else if let curatorRole = try? container.decodeIfPresent(VenueReference.self, forKey: .curator) {
            curatorId = curatorRole.id
        } else if let curatorRoles = try? container.decodeIfPresent([VenueReference].self, forKey: .curators) {
            curatorId = curatorRoles.first?.id
        } else if let altCurator = try? container.decodeIfPresent(String.self, forKey: .curatorIdAlt) {
            curatorId = altCurator
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
        } else if let altTalentInts = try? container.decodeIfPresent([Int].self, forKey: .talentIdsAlt) {
            talentIds = altTalentInts.map(String.init)
        } else if let memberRoleInts = try? container.decodeIfPresent([Int].self, forKey: .memberRoleIds) {
            talentIds = memberRoleInts.map(String.init)
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
        venueId: String?,
        venueName: String? = nil,
        roomId: String? = nil,
        images: [URL] = [],
        flyerImageUrl: String? = nil,
        flyerImageId: String? = nil,
        capacity: Int? = nil,
        ticketTypes: [TicketType] = [],
        publishState: PublishState = .draft,
        curatorId: String? = nil,
        talentIds: [String] = [],
        category: String? = nil,
        groupSlug: String? = nil,
        onlineURL: URL? = nil,
        timezone: String? = nil,
        isRecurring: Bool? = nil,
        attendeesVisible: Bool? = nil
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
        self.images = images
        self.flyerImageUrl = flyerImageUrl
        self.flyerImageId = flyerImageId
        self.capacity = capacity
        self.ticketTypes = ticketTypes
        self.publishState = publishState
        self.timezone = timezone
        self.curatorId = curatorId
        self.talentIds = talentIds
        self.category = category
        self.groupSlug = groupSlug
        self.onlineURL = onlineURL
        self.isRecurring = isRecurring
        self.attendeesVisible = attendeesVisible

        self.rawStartsAtString = nil
        self.rawEndsAtString = nil
        self.rawTimezoneIdentifier = timezone
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(description, forKey: .description)
        let encodingTimeZone = timezone.flatMap { TimeZone(identifier: $0) } ?? DateFormatterFactory.utcTimeZone
        let formatter = Event.payloadDateFormatter(timeZone: encodingTimeZone)

        try container.encode(formatter.string(from: startAt), forKey: .startsAt)
        try container.encode(formatter.string(from: endAt), forKey: .endAt)
        // API expects duration in hours
        if let durationMinutes, durationMinutes > 0 {
            try container.encode(durationMinutes / 60, forKey: .durationMinutes)
        }
        // Always encode venueId, including explicit null for online-only events
        try container.encode(venueId, forKey: .venueId)
        try container.encodeIfPresent(roomId, forKey: .roomId)
        try container.encode(images, forKey: .images)
        // Always encode flyer fields, including explicit null to support removal
        try container.encode(flyerImageUrl, forKey: .flyerImageUrl)
        try container.encode(flyerImageId, forKey: .flyerImageId)
        try container.encodeIfPresent(capacity, forKey: .capacity)
        try container.encode(ticketTypes, forKey: .ticketTypes)
        try container.encode(publishState, forKey: .publishState)
        try container.encodeIfPresent(curatorId, forKey: .curatorRoleId)
        try container.encodeIfPresent(curatorId, forKey: .curatorIdAlt)
        try container.encodeIfPresent(category, forKey: .category)
        try container.encodeIfPresent(groupSlug, forKey: .groupSlug)
        try container.encodeIfPresent(onlineURL, forKey: .onlineUrl)
        try container.encodeIfPresent(onlineURL, forKey: .url)
        try container.encodeIfPresent(isRecurring, forKey: .isRecurring)
        try container.encodeIfPresent(attendeesVisible, forKey: .attendeesVisible)
        if !talentIds.isEmpty {
            try container.encode(talentIds, forKey: .members)
            let memberInts: [Int] = talentIds.compactMap { Int($0) }
            if !memberInts.isEmpty {
                try container.encode(memberInts, forKey: .talentIdsAlt)
                try container.encode(memberInts, forKey: .memberRoleIds)
            }
        }
    }

    var venueDisplayDescription: String {
        if let venueName, !venueName.isEmpty {
            return venueName
        }
        if let venueId = venueId, !venueId.isEmpty {
            return venueId
        }
        // If no venue is set, this is an online event
        return "Online"
    }

    private static let iso8601WithFractional: ISO8601DateFormatter = {
        DateFormatterFactory.utcISO8601Formatter(includeFractionalSeconds: true)
    }()

    private static let iso8601: ISO8601DateFormatter = {
        DateFormatterFactory.utcISO8601Formatter()
    }()

    private static let fallbackDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
        formatter.timeZone = DateFormatterFactory.utcTimeZone
        return formatter
    }()

    private static let fallbackDateFormatterWithSpace: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.timeZone = DateFormatterFactory.utcTimeZone
        return formatter
    }()

    static func payloadDateFormatter(timeZone: TimeZone = DateFormatterFactory.utcTimeZone) -> DateFormatter {
        DateFormatterFactory.localPayloadFormatter(timeZone: timeZone)
    }

    private static func decodeDate(
        from container: KeyedDecodingContainer<CodingKeys>,
        keys: [CodingKeys],
        timeZone: TimeZone?
    ) throws -> Date? {
        let parsingTimeZone = DateFormatterFactory.utcTimeZone
        let fallbackParsingTimeZone = timeZone ?? DateFormatterFactory.utcTimeZone

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
                let timeZonesToTry: [TimeZone] = [parsingTimeZone, fallbackParsingTimeZone]
                for tz in timeZonesToTry {
                    let isoLocal = DateFormatter()
                    isoLocal.locale = Locale(identifier: "en_US_POSIX")
                    isoLocal.calendar = Calendar(identifier: .gregorian)
                    isoLocal.timeZone = tz
                    isoLocal.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
                    if let parsed = isoLocal.date(from: dateString) {
                        return parsed
                    }

                    let isoLocalFractional = DateFormatter()
                    isoLocalFractional.locale = Locale(identifier: "en_US_POSIX")
                    isoLocalFractional.calendar = Calendar(identifier: .gregorian)
                    isoLocalFractional.timeZone = tz
                    isoLocalFractional.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS"
                    if let parsed = isoLocalFractional.date(from: dateString) {
                        return parsed
                    }

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
                    spaceFormatter.timeZone = tz
                    if let parsed = spaceFormatter.date(from: dateString) {
                        return parsed
                    }
                }
            }
        }

        return nil
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
    var quantity: Int?

    init(id: String, name: String, price: Decimal? = nil, currency: String? = nil, quantity: Int? = nil) {
        self.id = id
        self.name = name
        self.price = price
        self.currency = currency
        self.quantity = quantity
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, price, currency, quantity
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
        let formatter = DateFormatterFactory.displayFormatter(
            timeZone: displayTimeZone(fallback: fallbackTimeZone),
            locale: Locale.current
        )
        return formatter.string(from: date)
    }
}
