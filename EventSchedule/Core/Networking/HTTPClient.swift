import Foundation

protocol HTTPClientProtocol {
    func request<T: Decodable>(
        _ path: String,
        method: HTTPMethod,
        query: [String: String?]?,
        body: Encodable?,
        instance: InstanceProfile
    ) async throws -> T

    func request<T: Decodable>(
        _ path: String,
        method: HTTPMethod,
        query: [String: String?]?,
        body: Encodable?,
        instance: InstanceProfile,
        additionalHeaders: [String: String]?
    ) async throws -> T

    func requestVoid(
        _ path: String,
        method: HTTPMethod,
        query: [String: String?]?,
        body: Encodable?,
        instance: InstanceProfile
    ) async throws

    func requestVoid(
        _ path: String,
        method: HTTPMethod,
        query: [String: String?]?,
        body: Encodable?,
        instance: InstanceProfile,
        additionalHeaders: [String: String]?
    ) async throws

    /// Low-level request returning raw Data and HTTPURLResponse. Use carefully.
    func requestRaw(
        _ path: String,
        method: HTTPMethod,
        query: [String: String?]?,
        body: Encodable?,
        instance: InstanceProfile,
        additionalHeaders: [String: String]?
    ) async throws -> (Data, HTTPURLResponse)
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
        instance: InstanceProfile,
        additionalHeaders: [String: String]? = nil
    ) async throws -> T {
        let (data, response) = try await performRequest(
            path,
            method: method,
            query: query,
            body: body,
            instance: instance,
            additionalHeaders: additionalHeaders
        )
        
        // Defensive: if 2xx but non-JSON content, surface a clear error early.
        if response.statusCode >= 200 && response.statusCode < 300 {
            let contentType = response.value(forHTTPHeaderField: "Content-Type")?.lowercased() ?? ""
            if !contentType.contains("json") {
                let bodyPreview = String(data: data, encoding: .utf8) ?? "<non-UTF8 body>"
                let limited = String(bodyPreview.prefix(1024))
                let urlString = response.url?.absoluteString ?? path
                DebugLogger.error("Non-JSON 2xx response for \(urlString). Hint: Verify instance.baseURL points to the API root and that X-API-Key is set. Content-Type=\(contentType). Body preview=\n\(limited)")
                throw APIError.decodingError(NSError(domain: "HTTPClient", code: -2, userInfo: [NSLocalizedDescriptionKey: "Non-JSON 2xx response"]), bodyPreview: limited)
            }
        }

        guard !data.isEmpty else {
            throw APIError.serverError(statusCode: response.statusCode, message: "Empty response body")
        }

        do {
            return try jsonDecoder.decode(T.self, from: data)
        } catch {
            // Fallback: attempt to normalize common list shapes for events
            do {
                // 1) Try top-level array of Event
                if let events = try? jsonDecoder.decode([Event].self, from: data) {
                    // Try to wrap into a common envelope and decode as T
                    let normalized = NormalizedEventsEnvelope(events: events)
                    if let wrapped = try? jsonEncoder.encode(normalized), let decoded = try? jsonDecoder.decode(T.self, from: wrapped) {
                        return decoded
                    }
                }
                // 2) Try { data: [Event] }
                if let envelope = try? jsonDecoder.decode(EventsDataEnvelope.self, from: data) {
                    let normalized = NormalizedEventsEnvelope(events: envelope.data)
                    if let wrapped = try? jsonEncoder.encode(normalized), let decoded = try? jsonDecoder.decode(T.self, from: wrapped) {
                        return decoded
                    }
                }
                // 3) Last-resort normalization using JSONSerialization for loosely typed payloads
                if
                    let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                    let array = json["data"] as? [Any]
                {
                    let normalized: [String: Any] = ["events": array]
                    if JSONSerialization.isValidJSONObject(normalized),
                       let wrapped = try? JSONSerialization.data(withJSONObject: normalized),
                       let decoded = try? jsonDecoder.decode(T.self, from: wrapped) {
                        return decoded
                    }
                }
            }
            let bodyPreview = String(data: data, encoding: .utf8) ?? "<non-UTF8 body>"
            DebugLogger.error("Decoding failed for \(T.self). Error: \(error.localizedDescription)")
            DebugLogger.error("Status OK, body:\n\(bodyPreview)")
            throw APIError.decodingError(error, bodyPreview: bodyPreview)
        }
    }

    // Overload without additionalHeaders for backward compatibility
    func request<T: Decodable>(
        _ path: String,
        method: HTTPMethod = .get,
        query: [String: String?]? = nil,
        body: Encodable? = nil,
        instance: InstanceProfile
    ) async throws -> T {
        return try await request(path, method: method, query: query, body: body, instance: instance, additionalHeaders: nil)
    }

    func requestVoid(
        _ path: String,
        method: HTTPMethod,
        query: [String: String?]? = nil,
        body: Encodable? = nil,
        instance: InstanceProfile,
        additionalHeaders: [String: String]? = nil
    ) async throws {
        _ = try await performRequest(path, method: method, query: query, body: body, instance: instance, additionalHeaders: additionalHeaders)
    }

    /// Perform a request and return the raw Data and HTTPURLResponse. Useful when callers
    /// need to inspect the raw body or status code even if decoding fails.
    func requestRaw(
        _ path: String,
        method: HTTPMethod = .get,
        query: [String: String?]? = nil,
        body: Encodable? = nil,
        instance: InstanceProfile,
        additionalHeaders: [String: String]? = nil
    ) async throws -> (Data, HTTPURLResponse) {
        return try await performRequest(path, method: method, query: query, body: body, instance: instance, additionalHeaders: additionalHeaders)
    }

    // Overload without additionalHeaders for backward compatibility
    func requestVoid(
        _ path: String,
        method: HTTPMethod,
        query: [String: String?]? = nil,
        body: Encodable? = nil,
        instance: InstanceProfile
    ) async throws {
        _ = try await performRequest(path, method: method, query: query, body: body, instance: instance, additionalHeaders: nil)
    }

    private func performRequest(
        _ path: String,
        method: HTTPMethod,
        query: [String: String?]?,
        body: Encodable?,
        instance: InstanceProfile,
        additionalHeaders: [String: String]? = nil
    ) async throws -> (Data, HTTPURLResponse) {
        DebugLogger.network("HTTPClient.performRequest path=\(path) base=\(instance.baseURL.absoluteString)")
        
        guard var urlComponents = URLComponents(url: instance.baseURL, resolvingAgainstBaseURL: false) else {
            DebugLogger.error("HTTPClient: failed to construct URLComponents for base=\(instance.baseURL) and path=\(path)")
            throw APIError.invalidURL
        }

        // If the caller provides a relative path, append it to the base URL's path.
        // Otherwise (leading slash), treat it as an absolute path to avoid altering
        // existing behaviors that rely on explicit absolute paths (e.g. branding).
        if path.hasPrefix("/") {
            urlComponents.path = path
        } else {
            let basePath = urlComponents.path
            let trimmedBasePath = basePath.hasSuffix("/") ? String(basePath.dropLast()) : basePath
            urlComponents.path = (trimmedBasePath.isEmpty ? "" : trimmedBasePath) + "/" + path
        }

        if let query = query {
            urlComponents.queryItems = query.compactMap { key, value in
                guard let value else { return nil }
                return URLQueryItem(name: key, value: value)
            }
        }

        guard let url = urlComponents.url else {
            DebugLogger.error("HTTPClient: failed to construct URL for base=\(instance.baseURL) and path=\(path)")
            throw APIError.invalidURL
        }

        DebugLogger.network("Resolved URL: \(url.absoluteString)")

        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        // Force fresh data - tell backend and any intermediary caches not to use cached responses
        request.setValue("no-cache, no-store, must-revalidate", forHTTPHeaderField: "Cache-Control")
        request.setValue("no-cache", forHTTPHeaderField: "Pragma")

        // Inject API key header from APIKeyStore
        if let apiKey = APIKeyStore.shared.load(for: instance) {
            request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
            DebugLogger.network("Auth header: X-API-Key: <redacted>")
        } else {
            DebugLogger.network("Auth header: no API key available for instance \(instance.displayName)")
        }

        // Add any additional headers (e.g., CSRF tokens)
        if let additionalHeaders = additionalHeaders {
            for (key, value) in additionalHeaders {
                request.setValue(value, forHTTPHeaderField: key)
                DebugLogger.network("Additional header: \(key): <redacted>")
            }
        }

        DebugLogger.network("Request headers: \(request.allHTTPHeaderFields ?? [:])")

        if let body = body {
            do {
                let encoded = try jsonEncoder.encode(AnyEncodable(body))
                request.httpBody = encoded
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                if let body = request.httpBody, let s = String(data: body, encoding: .utf8) {
                    DebugLogger.network("Request body: \(s.prefix(1024))")
                }
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
            DebugLogger.error("HTTPClient: network error for \(request.httpMethod ?? "<nil>") \(request.url?.absoluteString ?? "<nil>") error=\(error.localizedDescription)")
            throw APIError.networkError(error)
        }

        if let http = response as? HTTPURLResponse {
            let contentType = http.value(forHTTPHeaderField: "Content-Type") ?? "<nil>"
            DebugLogger.network("HTTP ⬅️ status=\(http.statusCode) url=\(http.url?.absoluteString ?? "<nil>") content-type=\(contentType)")
            let preview = String(data: data, encoding: .utf8) ?? "<non-UTF8 body>"
            let limited = String(preview.prefix(2048))
            if (200..<300).contains(http.statusCode) {
                DebugLogger.network("HTTP ⬅️ body (2xx): \(limited)")
                if !contentType.lowercased().contains("json") {
                    DebugLogger.network("Warning: 2xx response with non-JSON content-type: \(contentType)")
                }
            } else {
                DebugLogger.network("HTTP ⬅️ body (non-2xx): \(limited)")
            }
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.unknown
        }

        switch httpResponse.statusCode {
        case 200..<300:
            return (data, httpResponse)
        case 401:
            DebugLogger.error("HTTPClient: unauthorized response (401) for \(httpResponse.url?.absoluteString ?? "<nil>")")
            throw APIError.unauthorized
        case 403:
            DebugLogger.error("HTTPClient: forbidden response (403) for \(httpResponse.url?.absoluteString ?? "<nil>")")
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
            DebugLogger.error("HTTPClient: rate limited (429) for \(httpResponse.url?.absoluteString ?? "<nil>") retryAfter=\(retryAfter?.description ?? "nil")")
            throw APIError.rateLimited(retryAfter: retryAfter)
        default:
            let message = String(data: data, encoding: .utf8)
            DebugLogger.error("HTTPClient: server error status=\(httpResponse.statusCode) url=\(httpResponse.url?.absoluteString ?? "<nil>") message=\(message ?? "<no body>")")
            throw APIError.serverError(statusCode: httpResponse.statusCode, message: message)
        }
    }
}

private struct NormalizedEventsEnvelope: Encodable {
    let events: [Event]
}

private struct EventsDataEnvelope: Decodable {
    let data: [Event]
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
