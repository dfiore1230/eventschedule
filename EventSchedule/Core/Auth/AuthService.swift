import Foundation

struct AuthService {
    let httpClient: HTTPClientProtocol

    func login(email: String, password: String, instance: InstanceProfile) async throws -> AuthSession {
        guard let endpoint = instance.authEndpoints?["login"] ?? instance.authEndpoints?["token"] else {
            throw APIError.invalidURL
        }

        let (path, query) = endpoint.asPathAndQuery()

        let response: AuthTokenResponse
        switch instance.authMethod {
        case .oauth2:
            let request = OAuthPasswordRequest(username: email, password: password)
            response = try await httpClient.request(path, method: .post, query: query, body: request, instance: instance)
        case .sanctum, .jwt:
            let request = UsernamePasswordRequest(email: email, password: password)
            response = try await httpClient.request(path, method: .post, query: query, body: request, instance: instance)
        }

        guard let token = response.resolvedToken else {
            throw APIError.serverError(statusCode: 0, message: "Login succeeded but no token was returned.")
        }

        let expiry: Date?
        if let expiresIn = response.resolvedExpiry {
            expiry = Date().addingTimeInterval(expiresIn)
        } else {
            expiry = nil
        }

        let session = AuthSession(token: token, expiryDate: expiry)
        AuthTokenStore.shared.save(session: session, for: instance)
        return session
    }
}

private extension URL {
    func asPathAndQuery() -> (String, [String: String?]?) {
        let components = URLComponents(url: self, resolvingAgainstBaseURL: false)
        let queryItems = components?.queryItems ?? []
        let query: [String: String?]? = queryItems.isEmpty ? nil :
            Dictionary(uniqueKeysWithValues: queryItems.map { ($0.name, $0.value) })
        return (components?.path ?? path, query)
    }
}

private struct UsernamePasswordRequest: Encodable {
    let email: String
    let password: String
}

private struct OAuthPasswordRequest: Encodable {
    let username: String
    let password: String
    let grantType: String = "password"

    enum CodingKeys: String, CodingKey {
        case username
        case password
        case grantType = "grant_type"
    }
}

private struct AuthTokenResponse: Decodable {
    let token: String?
    let accessToken: String?
    let bearerToken: String?
    let expiresIn: TimeInterval?
    let expires_in: TimeInterval?

    enum CodingKeys: String, CodingKey {
        case token
        case accessToken = "access_token"
        case bearerToken = "bearer_token"
        case expiresIn = "expiresIn"
        case expires_in
    }

    var resolvedToken: String? {
        token ?? accessToken ?? bearerToken
    }

    var resolvedExpiry: TimeInterval? {
        expiresIn ?? expires_in
    }
}
