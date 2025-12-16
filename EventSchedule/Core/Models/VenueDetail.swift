import Foundation

/// Extended venue model with full details matching API structure
struct VenueDetail: Identifiable, Codable, Equatable {
    let id: Int
    var name: String
    var email: String?
    var phone: String?
    var website: String?
    var description: String?
    var address1: String?
    var address2: String?
    var city: String?
    var state: String?
    var postalCode: String?
    var countryCode: String?
    var formattedAddress: String?
    var geoLat: Double?
    var geoLon: Double?
    var timezone: String?
    var subdomain: String?
    var createdAt: Date?
    var updatedAt: Date?
    
    // Computed properties for convenience
    var displayAddress: String {
        if let formatted = formattedAddress, !formatted.isEmpty {
            return formatted
        }
        var parts: [String] = []
        if let addr = address1, !addr.isEmpty { parts.append(addr) }
        if let city = city, !city.isEmpty { parts.append(city) }
        if let state = state, !state.isEmpty { parts.append(state) }
        if let postal = postalCode, !postal.isEmpty { parts.append(postal) }
        return parts.joined(separator: ", ")
    }
    
    var hasLocation: Bool {
        geoLat != nil && geoLon != nil
    }
    
    init(
        id: Int,
        name: String,
        email: String? = nil,
        phone: String? = nil,
        website: String? = nil,
        description: String? = nil,
        address1: String? = nil,
        address2: String? = nil,
        city: String? = nil,
        state: String? = nil,
        postalCode: String? = nil,
        countryCode: String? = nil,
        formattedAddress: String? = nil,
        geoLat: Double? = nil,
        geoLon: Double? = nil,
        timezone: String? = nil,
        subdomain: String? = nil,
        createdAt: Date? = nil,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.email = email
        self.phone = phone
        self.website = website
        self.description = description
        self.address1 = address1
        self.address2 = address2
        self.city = city
        self.state = state
        self.postalCode = postalCode
        self.countryCode = countryCode
        self.formattedAddress = formattedAddress
        self.geoLat = geoLat
        self.geoLon = geoLon
        self.timezone = timezone
        self.subdomain = subdomain
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case email
        case phone
        case website
        case description
        case address1
        case address2
        case city
        case state
        case postalCode = "postal_code"
        case countryCode = "country_code"
        case formattedAddress = "formatted_address"
        case geoLat = "geo_lat"
        case geoLon = "geo_lon"
        case timezone
        case subdomain
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(Int.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        email = try container.decodeIfPresent(String.self, forKey: .email)
        phone = try container.decodeIfPresent(String.self, forKey: .phone)
        website = try container.decodeIfPresent(String.self, forKey: .website)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        address1 = try container.decodeIfPresent(String.self, forKey: .address1)
        address2 = try container.decodeIfPresent(String.self, forKey: .address2)
        city = try container.decodeIfPresent(String.self, forKey: .city)
        state = try container.decodeIfPresent(String.self, forKey: .state)
        postalCode = try container.decodeIfPresent(String.self, forKey: .postalCode)
        countryCode = try container.decodeIfPresent(String.self, forKey: .countryCode)
        formattedAddress = try container.decodeIfPresent(String.self, forKey: .formattedAddress)
        geoLat = try container.decodeIfPresent(Double.self, forKey: .geoLat)
        geoLon = try container.decodeIfPresent(Double.self, forKey: .geoLon)
        timezone = try container.decodeIfPresent(String.self, forKey: .timezone)
        subdomain = try container.decodeIfPresent(String.self, forKey: .subdomain)
        
        // Handle date decoding
        let dateFormatter = ISO8601DateFormatter()
        if let createdString = try container.decodeIfPresent(String.self, forKey: .createdAt) {
            createdAt = dateFormatter.date(from: createdString)
        } else {
            createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
        }
        if let updatedString = try container.decodeIfPresent(String.self, forKey: .updatedAt) {
            updatedAt = dateFormatter.date(from: updatedString)
        } else {
            updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(email, forKey: .email)
        try container.encodeIfPresent(phone, forKey: .phone)
        try container.encodeIfPresent(website, forKey: .website)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encodeIfPresent(address1, forKey: .address1)
        try container.encodeIfPresent(address2, forKey: .address2)
        try container.encodeIfPresent(city, forKey: .city)
        try container.encodeIfPresent(state, forKey: .state)
        try container.encodeIfPresent(postalCode, forKey: .postalCode)
        try container.encodeIfPresent(countryCode, forKey: .countryCode)
        try container.encodeIfPresent(formattedAddress, forKey: .formattedAddress)
        try container.encodeIfPresent(geoLat, forKey: .geoLat)
        try container.encodeIfPresent(geoLon, forKey: .geoLon)
        try container.encodeIfPresent(timezone, forKey: .timezone)
        try container.encodeIfPresent(subdomain, forKey: .subdomain)
        try container.encodeIfPresent(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(updatedAt, forKey: .updatedAt)
    }
    
    /// Convert to simple Venue reference for use in other models
    func toVenue() -> Venue {
        Venue(id: String(id), name: name)
    }
}
