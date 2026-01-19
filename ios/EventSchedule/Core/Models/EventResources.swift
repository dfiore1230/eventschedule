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
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(type, forKey: .type)
    }
}

struct EventResources: Decodable, Equatable {
    let venues: [EventRole]
    let curators: [EventRole]
    let talent: [EventRole]
    let categories: [String]
    let groups: [EventGroup]

    enum CodingKeys: String, CodingKey {
        case data
        case venues
        case curators
        case talent
        case categories
        case groups
    }

    init(
        venues: [EventRole] = [],
        curators: [EventRole] = [],
        talent: [EventRole] = [],
        categories: [String] = [],
        groups: [EventGroup] = []
    ) {
        self.venues = venues
        self.curators = curators
        self.talent = talent
        self.categories = categories
        self.groups = groups
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // 1) Try nested data container first: { data: { venues: [], curators: [], talent: [] } }
        if let nested = try? container.nestedContainer(keyedBy: CodingKeys.self, forKey: .data) {
            let v = (try? nested.decode([EventRole].self, forKey: .venues)) ?? []
            let c = (try? nested.decode([EventRole].self, forKey: .curators)) ?? []
            let t = (try? nested.decode([EventRole].self, forKey: .talent)) ?? []
            let cats = (try? nested.decode([String].self, forKey: .categories)) ?? []
            let g = (try? nested.decode([EventGroup].self, forKey: .groups)) ?? []
            venues = v
            curators = c
            talent = t
            categories = cats
            groups = g
            return
        }

        // 2) Fall back to top-level keys: { venues: [], curators: [], talent: [] }
        if container.contains(.venues) || container.contains(.curators) || container.contains(.talent) {
            venues = (try? container.decode([EventRole].self, forKey: .venues)) ?? []
            curators = (try? container.decode([EventRole].self, forKey: .curators)) ?? []
            talent = (try? container.decode([EventRole].self, forKey: .talent)) ?? []
            categories = (try? container.decode([String].self, forKey: .categories)) ?? []
            groups = (try? container.decode([EventGroup].self, forKey: .groups)) ?? []
            return
        }

        // 3) Default to empty if neither shape is present
        venues = []
        curators = []
        talent = []
        categories = []
        groups = []
    }

    private static func decodeResources(from decoder: Decoder) throws -> EventResources {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let venues = try container.decodeIfPresent([EventRole].self, forKey: .venues) ?? []
        let curators = try container.decodeIfPresent([EventRole].self, forKey: .curators) ?? []
        let talent = try container.decodeIfPresent([EventRole].self, forKey: .talent) ?? []
        let categories = try container.decodeIfPresent([String].self, forKey: .categories) ?? []
        let groups = try container.decodeIfPresent([EventGroup].self, forKey: .groups) ?? []
        return EventResources(venues: venues, curators: curators, talent: talent, categories: categories, groups: groups)
    }
}

struct EventGroup: Decodable, Identifiable, Equatable {
    let id: String
    let name: String
    let slug: String

    init(id: String, name: String, slug: String) {
        self.id = id
        self.name = name
        self.slug = slug
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let identifier = try container.decodeIfPresent(String.self, forKey: .id)
            ?? container.decodeIfPresent(String.self, forKey: .slug)
            ?? UUID().uuidString
        id = identifier
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? identifier
        slug = try container.decodeIfPresent(String.self, forKey: .slug) ?? identifier
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case slug
    }
}

