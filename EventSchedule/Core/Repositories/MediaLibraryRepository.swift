import Foundation

protocol MediaLibraryRepositoryProtocol {
    func fetchMedia(instance: InstanceProfile, page: Int?, perPage: Int?) async throws -> MediaLibraryResponse
    /// Fetch all media items by paging through results. Returns a flattened array of MediaItem.
    func fetchAllMedia(instance: InstanceProfile) async throws -> [MediaItem]
    func deleteMedia(id: String, instance: InstanceProfile) async throws
}

final class RemoteMediaLibraryRepository: MediaLibraryRepositoryProtocol {
    private let httpClient: HTTPClientProtocol
    
    init(httpClient: HTTPClientProtocol = HTTPClient()) {
        self.httpClient = httpClient
    }
    
    func fetchMedia(instance: InstanceProfile, page: Int? = nil, perPage: Int? = nil) async throws -> MediaLibraryResponse {
        var queryParams: [String: String?] = [:]
        if let page = page {
            queryParams["page"] = String(page)
        }
        if let perPage = perPage {
            queryParams["per_page"] = String(perPage)
        } else {
            queryParams["per_page"] = "100" // Default
        }
        
        let response: MediaLibraryResponse = try await httpClient.request(
            "/api/media",
            method: .get,
            query: queryParams,
            body: (nil as (any Encodable)?),
            instance: instance
        )
        
        return response
    }

    func fetchAllMedia(instance: InstanceProfile) async throws -> [MediaItem] {
        var page = 1
        let perPage = 1000
        var all: [MediaItem] = []

        while true {
            DebugLogger.network("MediaLibrary: fetching page=\(page) per_page=\(perPage)")
            let resp = try await fetchMedia(instance: instance, page: page, perPage: perPage)
            DebugLogger.network("MediaLibrary: page=\(resp.pagination.currentPage) last=\(resp.pagination.lastPage) items=\(resp.data.count)")
            all.append(contentsOf: resp.data)

            // Prefer authoritative pagination info when available
            if resp.pagination.currentPage >= resp.pagination.lastPage { break }

            page += 1
            // safety: avoid infinite loops
            if page > 1000 { break }
        }

        DebugLogger.network("MediaLibrary: fetched total items=\(all.count)")
        return all
    }
    
    func deleteMedia(id: String, instance: InstanceProfile) async throws {
        try await httpClient.requestVoid(
            "/api/media/\(id)",
            method: .delete,
            query: nil,
            body: (nil as (any Encodable)?),
            instance: instance
        )
    }
}
