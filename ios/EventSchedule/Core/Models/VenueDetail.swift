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
    
    // Profile & Header Images
    var profileImageUrl: String?
    var headerImageUrl: String?
    var backgroundImageUrl: String? // Main background image for the venue
    
    // Privacy Settings
    var showEmail: Bool?
    
    // Schedule Style
    var scheduleBackgroundType: String? // "gradient", "solid", "image"
    var scheduleBackgroundImageUrl: String?
    var scheduleAccentColor: String?
    
    // Schedule Settings
    var scheduleLanguage: String?
    var scheduleTimezone: String?
    var schedule24Hour: Bool?
    
    // Subschedules
    var subschedules: [String]?
    
    // Auto Import Settings
    var autoImportUrls: [String]?
    var autoImportCities: [String]?
    
    // Rooms
    var rooms: [VenueRoom]?
    
    // Contacts
    var contacts: [VenueContact]?
    
    struct VenueRoom: Identifiable, Codable, Equatable {
        let id: String
        var name: String
        var capacity: Int?
        var description: String?
        
        init(id: String = UUID().uuidString, name: String, capacity: Int? = nil, description: String? = nil) {
            self.id = id
            self.name = name
            self.capacity = capacity
            self.description = description
        }
    }
    
    struct VenueContact: Identifiable, Codable, Equatable {
        let id: String
        var name: String
        var role: String?
        var email: String?
        var phone: String?
        
        init(id: String = UUID().uuidString, name: String, role: String? = nil, email: String? = nil, phone: String? = nil) {
            self.id = id
            self.name = name
            self.role = role
            self.email = email
            self.phone = phone
        }
    }
    
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
        updatedAt: Date? = nil,
        profileImageUrl: String? = nil,
        headerImageUrl: String? = nil,
        backgroundImageUrl: String? = nil,
        showEmail: Bool? = nil,
        scheduleBackgroundType: String? = nil,
        scheduleBackgroundImageUrl: String? = nil,
        scheduleAccentColor: String? = nil,
        scheduleLanguage: String? = nil,
        scheduleTimezone: String? = nil,
        schedule24Hour: Bool? = nil,
        subschedules: [String]? = nil,
        autoImportUrls: [String]? = nil,
        autoImportCities: [String]? = nil,
        rooms: [VenueRoom]? = nil,
        contacts: [VenueContact]? = nil
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
        self.profileImageUrl = profileImageUrl
        self.headerImageUrl = headerImageUrl
        self.backgroundImageUrl = backgroundImageUrl
        self.showEmail = showEmail
        self.scheduleBackgroundType = scheduleBackgroundType
        self.scheduleBackgroundImageUrl = scheduleBackgroundImageUrl
        self.scheduleAccentColor = scheduleAccentColor
        self.scheduleLanguage = scheduleLanguage
        self.scheduleTimezone = scheduleTimezone
        self.schedule24Hour = schedule24Hour
        self.subschedules = subschedules
        self.autoImportUrls = autoImportUrls
        self.autoImportCities = autoImportCities
        self.rooms = rooms
        self.contacts = contacts
    }
    
    // Removed explicit CodingKeys and custom init/encode - let convertFromSnakeCase handle everything automatically
    
    /// Convert to simple Venue reference for use in other models
    func toVenue() -> Venue {
        Venue(id: String(id), name: name)
    }
}
