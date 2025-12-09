import Foundation

struct EventRole: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let type: String

    enum CodingKeys: String, CodingKey {
        case id
        case encodedId
        case name
        case title
        case label
        case type
        case roleType
    }

    init(id: String, name: String, type: String) {
        self.id = id
        self.name = name
        self.type = type
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if let encodedId = try container.decodeIfPresent(String.self, forKey: .encodedId) {
            id = encodedId
        } else {
            id = try container.decode(String.self, forKey: .id)
        }

        let decodedName = try container.decodeIfPresent(String.self, forKey: .name)
            ?? container.decodeIfPresent(String.self, forKey: .title)
            ?? container.decodeIfPresent(String.self, forKey: .label)
            ?? id
        name = decodedName.isEmpty ? id : decodedName

        type = try container.decodeIfPresent(String.self, forKey: .type)
            ?? container.decodeIfPresent(String.self, forKey: .roleType)
            ?? ""
    }
}

struct EventResources: Decodable, Equatable {
    let venues: [EventRole]
    let curators: [EventRole]
    let talent: [EventRole]

    enum CodingKeys: String, CodingKey {
        case data
        case venues
        case curators
        case talent
    }

    init(venues: [EventRole] = [], curators: [EventRole] = [], talent: [EventRole] = []) {
        self.venues = venues
        self.curators = curators
        self.talent = talent
    }

    init(from decoder: Decoder) throws {
        if let direct = try? EventResources.decodeResources(from: decoder) {
            self = direct
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let nested = try? container.nestedContainer(keyedBy: CodingKeys.self, forKey: .data) {
            venues = (try? nested.decode([EventRole].self, forKey: .venues)) ?? []
            curators = (try? nested.decode([EventRole].self, forKey: .curators)) ?? []
            talent = (try? nested.decode([EventRole].self, forKey: .talent)) ?? []
            return
        }

        venues = (try? container.decode([EventRole].self, forKey: .venues)) ?? []
        curators = (try? container.decode([EventRole].self, forKey: .curators)) ?? []
        talent = (try? container.decode([EventRole].self, forKey: .talent)) ?? []
    }

    private static func decodeResources(from decoder: Decoder) throws -> EventResources {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let venues = try container.decodeIfPresent([EventRole].self, forKey: .venues) ?? []
        let curators = try container.decodeIfPresent([EventRole].self, forKey: .curators) ?? []
        let talent = try container.decodeIfPresent([EventRole].self, forKey: .talent) ?? []
        return EventResources(venues: venues, curators: curators, talent: talent)
    }
}
