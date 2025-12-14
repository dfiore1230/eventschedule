import Foundation

/// Extended venue model with full details including rooms, capacity, and ingress points
struct VenueDetail: Identifiable, Codable, Equatable {
    let id: String
    var name: String
    var address: Address?
    var rooms: [Room]
    var capacityByRoom: [String: Int]
    var seatingMapURL: URL?
    var timezone: String?
    var ingressPoints: [IngressPoint]
    var images: [URL]
    var contact: ContactInfo?
    
    struct Address: Codable, Equatable {
        var street: String?
        var street2: String?
        var city: String?
        var state: String?
        var postalCode: String?
        var country: String?
        var latitude: Double?
        var longitude: Double?
        
        var formatted: String {
            var parts: [String] = []
            if let street = street, !street.isEmpty { parts.append(street) }
            if let city = city, !city.isEmpty { parts.append(city) }
            if let state = state, !state.isEmpty { parts.append(state) }
            if let postalCode = postalCode, !postalCode.isEmpty { parts.append(postalCode) }
            return parts.joined(separator: ", ")
        }
    }
    
    struct Room: Identifiable, Codable, Equatable {
        let id: String
        var name: String
        var capacity: Int?
        var floor: String?
        var notes: String?
    }
    
    struct IngressPoint: Identifiable, Codable, Equatable {
        let id: String
        var name: String
        var type: IngressType
        var roomId: String?
        var isActive: Bool
        
        enum IngressType: String, Codable {
            case main
            case secondary
            case vip
            case staff
            case emergency
        }
    }
    
    struct ContactInfo: Codable, Equatable {
        var phone: String?
        var email: String?
        var website: URL?
    }
    
    init(
        id: String,
        name: String,
        address: Address? = nil,
        rooms: [Room] = [],
        capacityByRoom: [String: Int] = [:],
        seatingMapURL: URL? = nil,
        timezone: String? = nil,
        ingressPoints: [IngressPoint] = [],
        images: [URL] = [],
        contact: ContactInfo? = nil
    ) {
        self.id = id
        self.name = name
        self.address = address
        self.rooms = rooms
        self.capacityByRoom = capacityByRoom
        self.seatingMapURL = seatingMapURL
        self.timezone = timezone
        self.ingressPoints = ingressPoints
        self.images = images
        self.contact = contact
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case title
        case address
        case rooms
        case capacityByRoom = "capacity_by_room"
        case seatingMapURL = "seating_map_url"
        case timezone
        case ingressPoints = "ingress_points"
        case images
        case contact
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(String.self, forKey: .id)
        
        // Name can be in 'name' or 'title' field
        if let nameDecode = try container.decodeIfPresent(String.self, forKey: .name) {
            name = nameDecode
        } else {
            name = try container.decodeIfPresent(String.self, forKey: .title) ?? id
        }
        
        address = try container.decodeIfPresent(Address.self, forKey: .address)
        rooms = try container.decodeIfPresent([Room].self, forKey: .rooms) ?? []
        capacityByRoom = try container.decodeIfPresent([String: Int].self, forKey: .capacityByRoom) ?? [:]
        
        if let urlString = try container.decodeIfPresent(String.self, forKey: .seatingMapURL),
           let url = URL(string: urlString) {
            seatingMapURL = url
        } else {
            seatingMapURL = try container.decodeIfPresent(URL.self, forKey: .seatingMapURL)
        }
        
        timezone = try container.decodeIfPresent(String.self, forKey: .timezone)
        ingressPoints = try container.decodeIfPresent([IngressPoint].self, forKey: .ingressPoints) ?? []
        images = try container.decodeIfPresent([URL].self, forKey: .images) ?? []
        contact = try container.decodeIfPresent(ContactInfo.self, forKey: .contact)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(address, forKey: .address)
        try container.encode(rooms, forKey: .rooms)
        try container.encode(capacityByRoom, forKey: .capacityByRoom)
        try container.encodeIfPresent(seatingMapURL, forKey: .seatingMapURL)
        try container.encodeIfPresent(timezone, forKey: .timezone)
        try container.encode(ingressPoints, forKey: .ingressPoints)
        try container.encode(images, forKey: .images)
        try container.encodeIfPresent(contact, forKey: .contact)
    }
    
    /// Convert to simple Venue reference for use in other models
    func toVenue() -> Venue {
        Venue(id: id, name: name)
    }
}
