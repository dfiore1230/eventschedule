import Foundation

struct Talent: Identifiable, Codable, Equatable {
    let id: Int
    var name: String
    var email: String?
    var phone: String?
    var website: String?
    var description: String?
    var address1: String?
    var city: String?
    var state: String?
    var postalCode: String?
    var countryCode: String?
    var timezone: String?
    var subdomain: String?
    var createdAt: Date?
    var updatedAt: Date?
    
    // Profile & Header Images
    var profileImageUrl: String?
    var headerImageUrl: String?
    var backgroundImageUrl: String? // Main background image for the talent
    
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
    
    // Subschedules (stored as JSON array of schedule IDs or names)
    var subschedules: [String]?
    
    // Auto Import Settings
    var autoImportUrls: [String]?
    var autoImportCities: [String]?
    
    // Computed property for backward compatibility
    var role: String? {
        description
    }
    
    var bio: String? {
        description
    }
    
    init(
        id: Int,
        name: String,
        email: String? = nil,
        phone: String? = nil,
        website: String? = nil,
        description: String? = nil,
        address1: String? = nil,
        city: String? = nil,
        state: String? = nil,
        postalCode: String? = nil,
        countryCode: String? = nil,
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
        autoImportCities: [String]? = nil
    ) {
        self.id = id
        self.name = name
        self.email = email
        self.phone = phone
        self.website = website
        self.description = description
        self.address1 = address1
        self.city = city
        self.state = state
        self.postalCode = postalCode
        self.countryCode = countryCode
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
    }
    
    // Removed explicit CodingKeys and custom init/encode - let convertFromSnakeCase handle everything automatically
}
