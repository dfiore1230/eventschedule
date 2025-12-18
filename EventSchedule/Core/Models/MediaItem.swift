import Foundation

struct MediaItem: Codable, Identifiable, Equatable {
    let id: Int
    let uuid: String
    let url: String
    let originalFilename: String
    let width: Int?
    let height: Int?
    let folder: String?
    let usageCount: Int
    let usages: [MediaUsage]
    let tags: [MediaTag]
    let variants: [MediaVariant]
    
    var thumbnailURL: String {
        // Use the original URL for thumbnails
        return url
    }
    
    var displayName: String {
        // Remove file extension and format nicely
        let name = originalFilename
            .replacingOccurrences(of: #"^(flyer_|banner_|profile_)"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\.[^.]+$"#, with: "", options: .regularExpression)
        return name.isEmpty ? originalFilename : name
    }
    
    struct MediaUsage: Codable, Equatable {
        let id: Int
        let context: String?
        let contextLabel: String?
        let type: String?
        let displayName: String?
        let usableId: Int?
        let variantId: Int?
    }
    
    struct MediaTag: Codable, Equatable {
        let id: Int
        let name: String
        let slug: String
    }
    
    struct MediaVariant: Codable, Equatable {
        let id: Int
        let label: String
        let url: String
        let width: Int?
        let height: Int?
    }
}

struct MediaLibraryResponse: Codable {
    let data: [MediaItem]
    let pagination: PaginationMeta
    
    struct PaginationMeta: Codable {
        let currentPage: Int
        let lastPage: Int
        let perPage: Int
        let total: Int
    }
}
