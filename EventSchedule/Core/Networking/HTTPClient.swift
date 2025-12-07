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

    init(
        urlSession: URLSession = .shared,
        jsonDecoder: JSONDecoder = JSONDecoder(),
        jsonEncoder: JSONEncoder = JSONEncoder()
    ) {
        self.urlSession = urlSession
        self.jsonDecoder = jsonDecoder
        self.jsonEncoder = jsonEncoder

        self.jsonDecoder.dateDecodingStrategy = .iso8601
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

        if !data.isEmpty {
            let contentType = response.value(forHTTPHeaderField: "Content-Type")?.lowercased()
            if contentType?.contains("json") == false {
                let bodyPreview = String(data: data, encoding: .utf8)
                DebugLogger.breakpoint("Unexpected content type \(contentType ?? "<nil>") for \(response.url?.absoluteString ?? "<nil>")")
                throw APIError.serverError(statusCode: response.statusCode, message: bodyPreview)
            }
        }

        do {
            return try jsonDecoder.decode(T.self, from: data)
        } catch {
            let bodyPreview = String(data: data, encoding: .utf8)
            DebugLogger.breakpoint("Failed to decode response for \(response.url?.absoluteString ?? "<nil>"): \(bodyPreview ?? "<non-UTF8 body>")")
            throw APIError.decodingError(error)
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

        // TODO: inject auth headers based on instance.authMethod & token store

        if let body = body {
            do {
                let encoded = try jsonEncoder.encode(AnyEncodable(body))
                request.httpBody = encoded
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            } catch {
                throw APIError.encodingError(error)
            }
        }

        DebugLogger.networkRequest(request)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await urlSession.data(for: request)
        } catch {
            DebugLogger.networkError(error, request: request)
            DebugLogger.breakpoint("Network layer error when requesting \(request.url?.absoluteString ?? "<nil>")")
            throw APIError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.unknown
        }

        DebugLogger.networkResponse(httpResponse, data: data)

        switch httpResponse.statusCode {
        case 200..<300:
            return (data, httpResponse)
        case 401:
            DebugLogger.breakpoint("Unauthorized response")
            throw APIError.unauthorized
        case 403:
            DebugLogger.breakpoint("Forbidden response")
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
            let retryAfterString = retryAfter.map { String($0) } ?? "nil"
            DebugLogger.breakpoint("Rate limited with retry after \(retryAfterString)" )
            throw APIError.rateLimited(retryAfter: retryAfter)
        default:
            let message = String(data: data, encoding: .utf8)
            DebugLogger.breakpoint("Server error \(httpResponse.statusCode): \(message ?? "<no body>")")
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
