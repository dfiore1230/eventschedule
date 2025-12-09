import Foundation

struct RolesAPIConfig {
    let baseURL: URL
    let apiKey: String

    init(baseURL: URL, apiKey: String) {
        self.baseURL = baseURL
        self.apiKey = apiKey
    }
}

enum RolesAPIError: Error, LocalizedError {
    case invalidURL
    case httpStatus(code: Int, body: String)
    case unexpectedContentType(contentType: String, bodyPreview: String)
    case decoding(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case let .httpStatus(code, body):
            return "HTTP \(code). Body: \(body.prefix(1024))"
        case let .unexpectedContentType(ct, preview):
            return "Unexpected Content-Type: \(ct). Body: \(preview)"
        case let .decoding(err):
            return "Decoding error: \(err.localizedDescription)"
        }
    }
}

final class RolesService {
    private let session: URLSession
    private let config: RolesAPIConfig

    init(session: URLSession = .shared, config: RolesAPIConfig) {
        self.session = session
        self.config = config
    }

    func listVenues(perPage: Int = 1000, name: String? = nil) async throws -> [Venue] {
        var components = URLComponents(url: config.baseURL.appendingPathComponent("/api/roles"), resolvingAgainstBaseURL: false)
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "type", value: "venue"),
            URLQueryItem(name: "per_page", value: String(min(max(perPage, 1), 1000)))
        ]
        if let name, !name.isEmpty {
            queryItems.append(URLQueryItem(name: "name", value: name))
        }
        components?.queryItems = queryItems

        guard let url = components?.url else { throw RolesAPIError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(config.apiKey, forHTTPHeaderField: "X-API-Key")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        guard (200...299).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "<non-utf8 body>"
            throw RolesAPIError.httpStatus(code: http.statusCode, body: body)
        }

        if let contentType = http.value(forHTTPHeaderField: "Content-Type"),
           !contentType.lowercased().contains("application/json") {
            let preview = String(data: data, encoding: .utf8) ?? "<non-utf8 body>"
            throw RolesAPIError.unexpectedContentType(contentType: contentType, bodyPreview: String(preview.prefix(512)))
        }

        struct RolesResponse: Decodable { let data: [RoleDTO] }
        struct RoleDTO: Decodable { let id: String; let name: String; let type: String }

        do {
            let decoded = try JSONDecoder().decode(RolesResponse.self, from: data)
            return decoded.data.filter { $0.type == "venue" }.map { Venue(id: $0.id, name: $0.name) }
        } catch {
            throw RolesAPIError.decoding(error)
        }
    }
}
