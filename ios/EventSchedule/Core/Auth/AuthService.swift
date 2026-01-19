import Foundation
import Security

// DebugLogger mirrors output to the Xcode console even when stdout/stderr
// are not presented as a TTY (e.g., when running under the debugger).
// Using it here keeps keychain diagnostics visible during debugging sessions.

/// API-key based authentication service.
///
/// This service replaces username/password login flows. Clients should:
/// 1) Discover `apiBase` from `/.well-known/eventschedule.json` and store it in `InstanceProfile.baseURL`.
/// 2) Persist an API key provided by the user (Settings → Integrations & API in the web UI).
/// 3) Send the API key on every request using the `X-API-Key` header.
///
/// Expected server errors:
/// - 401 Unauthorized: missing/invalid X-API-Key
/// - 423 Locked: key temporarily blocked after repeated failures
/// - 429 Too Many Requests: IP-level rate limiting
struct AuthService {
    let httpClient: HTTPClientProtocol

    init(httpClient: HTTPClientProtocol) {
        self.httpClient = httpClient
    }

    // MARK: - API Key Session

    struct APIKeySession: Equatable {
        let apiKey: String
    }

    /// Save an API key for the given instance.
    func save(apiKey: String, for instance: InstanceProfile) {
        APIKeyStore.shared.save(apiKey: apiKey, for: instance)
    }

    /// Load an API key for the given instance.
    func load(for instance: InstanceProfile) -> APIKeySession? {
        guard let key = APIKeyStore.shared.load(for: instance) else { return nil }
        return APIKeySession(apiKey: key)
    }

    /// Clear a stored API key for the given instance.
    func clear(for instance: InstanceProfile) {
        APIKeyStore.shared.clear(for: instance)
    }

    // MARK: - Request Helpers

    /// Prepare a URLRequest for a given path and optional query using the instance baseURL,
    /// attaching JSON headers and the X-API-Key header if available.
    func makeRequest(
        path: String,
        method: String = "GET",
        query: [String: String?]? = nil,
        instance: InstanceProfile,
        jsonBody: Data? = nil
    ) throws -> URLRequest {
        guard var components = URLComponents(url: instance.baseURL, resolvingAgainstBaseURL: false) else {
            throw APIError.serverError(statusCode: 0, message: "Invalid base URL for instance: \(instance.displayName)")
        }
        components.path = path
        if let query = query {
            components.queryItems = query.compactMap { key, value in
                guard let value else { return nil }
                return URLQueryItem(name: key, value: value)
            }
        }
        guard let url = components.url else {
            throw APIError.serverError(statusCode: 0, message: "Failed to construct URL for path: \(path)")
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let key = APIKeyStore.shared.load(for: instance) {
            request.setValue(key, forHTTPHeaderField: "X-API-Key")
        }

        request.httpBody = jsonBody
        return request
    }

    /// Perform a request through the shared URLSession and map common auth-related errors.
    func perform(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw APIError.serverError(statusCode: 0, message: "Non-HTTP response")
        }
        switch http.statusCode {
        case 401:
            throw APIError.unauthorized
        case 423, 429:
            throw APIError.serverError(statusCode: http.statusCode, message: nil)
        default:
            break
        }
        return (data, http)
    }

    // MARK: - Convenience JSON decoding

    func decodeJSON<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(T.self, from: data)
    }
}

// MARK: - URL helpers
private extension URL {
    func asPathAndQuery() -> (String, [String: String?]?) {
        let components = URLComponents(url: self, resolvingAgainstBaseURL: false)
        let queryItems = components?.queryItems ?? []
        let query: [String: String?]? = queryItems.isEmpty ? nil :
            Dictionary(uniqueKeysWithValues: queryItems.map { ($0.name, $0.value) })
        return (components?.path ?? path, query)
    }
}

// MARK: - APIKeyStore (singleton)
/// A Keychain-backed store for API keys.
final class APIKeyStore {
    static let shared = APIKeyStore()
    private init() {}

    // In-memory cache for quick access; source of truth is Keychain
    private var cache: [String: String] = [:]

    private let service: String = (Bundle.main.bundleIdentifier ?? "com.example.app") + ".apikey"

    /// Persist an API key for an instance.
    func save(apiKey: String, for instance: InstanceProfile) {
        let account = storageKey(for: instance)
        cache[account] = apiKey
        let data = Data(apiKey.utf8)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let attributes: [String: Any] = [
            kSecValueData as String: data
        ]

        let status: OSStatus
        if keychainItemExists(query: query) {
            status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        } else {
            var addQuery = query
            addQuery[kSecValueData as String] = data
            status = SecItemAdd(addQuery as CFDictionary, nil)
        }

        if status != errSecSuccess {
            DebugLogger.error("APIKeyStore: keychain save error: \(status)")
        }
    }

    /// Load an API key for an instance.
    func load(for instance: InstanceProfile) -> String? {
        let account = storageKey(for: instance)
        if let cached = cache[account] { return cached }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data, let key = String(data: data, encoding: .utf8) else {
            if status != errSecItemNotFound {
                DebugLogger.error("APIKeyStore: keychain load error: \(status)")
            }
            return nil
        }
        cache[account] = key
        return key
    }

    /// Clear the API key for an instance.
    func clear(for instance: InstanceProfile) {
        let account = storageKey(for: instance)
        cache.removeValue(forKey: account)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let status = SecItemDelete(query as CFDictionary)
        if status != errSecSuccess && status != errSecItemNotFound {
            DebugLogger.error("APIKeyStore: keychain delete error: \(status)")
        }
    }

    private func storageKey(for instance: InstanceProfile) -> String {
        return instance.baseURL.absoluteString
    }

    private func keychainItemExists(query: [String: Any]) -> Bool {
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        return status == errSecSuccess
    }
}
