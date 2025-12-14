import Foundation

struct Talent: Identifiable, Codable, Equatable {
    let id: String
    var name: String
    var role: String?
    var bio: String?
    var links: [String: URL]
    var images: [URL]
    var contact: ContactInfo?
    var availability: [AvailabilityPeriod]
    
    struct ContactInfo: Codable, Equatable {
        var email: String?
        var phone: String?
        var website: URL?
        var social: [String: String]
    }
    
    struct AvailabilityPeriod: Codable, Equatable {
        let startDate: Date
        let endDate: Date
        var notes: String?
    }
    
    init(
        id: String,
        name: String,
        role: String? = nil,
        bio: String? = nil,
        links: [String: URL] = [:],
        images: [URL] = [],
        contact: ContactInfo? = nil,
        availability: [AvailabilityPeriod] = []
    ) {
        self.id = id
        self.name = name
        self.role = role
        self.bio = bio
        self.links = links
        self.images = images
        self.contact = contact
        self.availability = availability
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case role
        case bio
        case description
        case links
        case images
        case contact
        case availability
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        role = try container.decodeIfPresent(String.self, forKey: .role)
        
        // Bio can be in 'bio' or 'description' field
        if let bioDecode = try container.decodeIfPresent(String.self, forKey: .bio) {
            bio = bioDecode
        } else {
            bio = try container.decodeIfPresent(String.self, forKey: .description)
        }
        
        // Links can be dictionary of URLs or array of strings
        if let linksDict = try? container.decodeIfPresent([String: URL].self, forKey: .links) {
            links = linksDict
        } else if let linksArray = try? container.decodeIfPresent([String].self, forKey: .links) {
            // Safely convert array of strings to dictionary of URLs
            var linksDict: [String: URL] = [:]
            for (index, urlString) in linksArray.enumerated() {
                if let url = URL(string: urlString) {
                    linksDict["link\(index)"] = url
                }
            }
            links = linksDict
        } else {
            links = [:]
        }
        
        images = try container.decodeIfPresent([URL].self, forKey: .images) ?? []
        contact = try container.decodeIfPresent(ContactInfo.self, forKey: .contact)
        availability = try container.decodeIfPresent([AvailabilityPeriod].self, forKey: .availability) ?? []
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(role, forKey: .role)
        try container.encodeIfPresent(bio, forKey: .bio)
        try container.encode(links, forKey: .links)
        try container.encode(images, forKey: .images)
        try container.encodeIfPresent(contact, forKey: .contact)
        try container.encode(availability, forKey: .availability)
    }
}
