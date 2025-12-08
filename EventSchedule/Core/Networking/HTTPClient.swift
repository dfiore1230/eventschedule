import Foundation

protocol HTTPClientProtocol {
    func request<T: Decodable>(
        _ path: String,
        method: HTTPMethod,
        query: [String: String?]?,
        body: Encodable?,
        instance: InstanceProfile
    ) async throws -> T

    func requestVoid(
        _ path: String,
        method: HTTPMethod,
        query: [String: String?]?,
        body: Encodable?,
        instance: InstanceProfile
    ) async throws
}

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
}

final class HTTPClient: HTTPClientProtocol {
    private let urlSession: URLSession
    private let jsonDecoder: JSONDecoder
    private let jsonEncoder: JSONEncoder
    private let tokenProvider: ((InstanceProfile) -> String?)?

    init(
        urlSession: URLSession = .shared,
        jsonDecoder: JSONDecoder = JSONDecoder(),
        jsonEncoder: JSONEncoder = JSONEncoder(),
        tokenProvider: ((InstanceProfile) -> String?)? = nil
    ) {
        self.urlSession = urlSession
        self.jsonDecoder = jsonDecoder
        self.jsonEncoder = jsonEncoder
        self.tokenProvider = tokenProvider

        self.jsonDecoder.keyDecodingStrategy = .convertFromSnakeCase
        self.jsonDecoder.dateDecodingStrategy = .iso8601
        self.jsonEncoder.keyEncodingStrategy = .convertToSnakeCase
        self.jsonEncoder.dateEncodingStrategy = .iso8601
    }

    func request<T: Decodable>(
        _ path: String,
        method: HTTPMethod = .get,
        query: [String: String?]? = nil,
        body: Encodable? = nil,
        instance: InstanceProfile
    ) async throws -> T {
        let (data, response) = try await performRequest(
            path,
            method: method,
            query: query,
            body: body,
            instance: instance
        )

        guard !data.isEmpty else {
            throw APIError.serverError(statusCode: response.statusCode, message: "Empty response body")
        }

        let contentType = response.value(forHTTPHeaderField: "Content-Type")?.lowercased()
        if contentType?.contains("json") == false {
            let bodyPreview = String(data: data, encoding: .utf8)
            throw APIError.serverError(statusCode: response.statusCode, message: bodyPreview)
        }

        do {
            return try jsonDecoder.decode(T.self, from: data)
        } catch {
            let bodyPreview = String(data: data, encoding: .utf8) ?? "<non-UTF8 body>"
            DebugLogger.error("Decoding failed for \(T.self). Status OK, body:\n\(bodyPreview)")
            throw APIError.decodingError(error, bodyPreview: bodyPreview)
        }
    }

    func requestVoid(
        _ path: String,
        method: HTTPMethod,
        query: [String: String?]? = nil,
        body: Encodable? = nil,
        instance: InstanceProfile
    ) async throws {
        _ = try await performRequest(path, method: method, query: query, body: body, instance: instance)
    }

    private func performRequest(
        _ path: String,
        method: HTTPMethod,
        query: [String: String?]?,
        body: Encodable?,
        instance: InstanceProfile
    ) async throws -> (Data, HTTPURLResponse) {
        guard var urlComponents = URLComponents(url: instance.baseURL, resolvingAgainstBaseURL: false) else {
            throw APIError.invalidURL
        }

        urlComponents.path = path.hasPrefix("/") ? path : "/" + path

        if let query = query {
            urlComponents.queryItems = query.compactMap { key, value in
                guard let value else { return nil }
                return URLQueryItem(name: key, value: value)
            }
        }

        guard let url = urlComponents.url else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        // Inject API key header from APIKeyStore
        if let apiKey = APIKeyStore.shared.load(for: instance) {
            request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
            DebugLogger.network("Auth header: X-API-Key: <redacted>")
        } else {
            DebugLogger.network("Auth header: no API key available for instance \(instance.displayName)")
        }

        if let body = body {
            do {
                let encoded = try jsonEncoder.encode(AnyEncodable(body))
                request.httpBody = encoded
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            } catch {
                throw APIError.encodingError(error)
            }
        }

        if let method = request.httpMethod {
            DebugLogger.network("HTTP ➡️ \(method) \(request.url?.absoluteString ?? "<nil>")")
        } else {
            DebugLogger.network("HTTP ➡️ <unknown method> \(request.url?.absoluteString ?? "<nil>")")
        }
        if let headers = request.allHTTPHeaderFields { DebugLogger.network("HTTP headers: \(headers)") }
        if let body = request.httpBody, let str = String(data: body, encoding: .utf8) { DebugLogger.network("HTTP body: \(str)") }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await urlSession.data(for: request)
        } catch {
            throw APIError.networkError(error)
        }

        if let http = response as? HTTPURLResponse {
            let contentType = http.value(forHTTPHeaderField: "Content-Type") ?? "<nil>"
            DebugLogger.network("HTTP ⬅️ \(http.statusCode) \(http.url?.absoluteString ?? "<nil>") content-type: \(contentType)")
            let preview = String(data: data, encoding: .utf8) ?? "<non-UTF8 body>"
            if (200..<300).contains(http.statusCode) {
                DebugLogger.network("HTTP ⬅️ body: \(preview)")
            } else {
                DebugLogger.network("HTTP ⬅️ body (non-2xx): \(preview)")
            }
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.unknown
        }

        switch httpResponse.statusCode {
        case 200..<300:
            return (data, httpResponse)
        case 401:
            throw APIError.unauthorized
        case 403:
            throw APIError.forbidden
        case 429:
            // Parse Retry-After header. It can be either an integer number of seconds or an HTTP-date.
            let retryAfterHeader = httpResponse.value(forHTTPHeaderField: "Retry-After")
            let retryAfter: TimeInterval? = retryAfterHeader.flatMap { value in
                // First, try to parse as seconds (Double)
                if let seconds = Double(value) {
                    return TimeInterval(seconds)
                }
                // Optionally, try to parse HTTP-date formats if needed in the future.
                return nil
            }
            throw APIError.rateLimited(retryAfter: retryAfter)
        default:
            let message = String(data: data, encoding: .utf8)
            throw APIError.serverError(statusCode: httpResponse.statusCode, message: message)
        }
    }
}

private struct AnyEncodable: Encodable {
    private let _encode: (Encoder) throws -> Void

    init<T: Encodable>(_ wrapped: T) {
        self._encode = wrapped.encode
    }

    func encode(to encoder: Encoder) throws {
        try _encode(encoder)
    }
}
