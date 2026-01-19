import Foundation
import Combine

// DebugLogger mirrors output to the Xcode console even when stdout/stderr
// are not presented as a TTY (e.g., when running under the debugger).
// Using it here keeps token store diagnostics visible during debugging sessions.

struct AuthSession: Codable, Equatable {
    let token: String
    let expiryDate: Date?
}

final class AuthTokenStore: ObservableObject {
    static let shared = AuthTokenStore()

    @Published private var sessions: [UUID: AuthSession] {
        didSet { persist() }
    }

    private static let storageKey = "authSessions_v1"

    private init() {
        self.sessions = AuthTokenStore.loadPersisted()
    }

    func token(for instance: InstanceProfile) -> String? {
        session(for: instance)?.token
    }

    func session(for instance: InstanceProfile) -> AuthSession? {
        sessions[identifier(for: instance)]
    }

    func save(session: AuthSession, for instance: InstanceProfile) {
        sessions[identifier(for: instance)] = session
    }

    func clearSession(for instance: InstanceProfile) {
        sessions.removeValue(forKey: identifier(for: instance))
    }
    
    func validSession(for instance: InstanceProfile) -> AuthSession? {
        guard let session = session(for: instance) else { return nil }
        if let expiry = session.expiryDate {
            let expired = expiry < Date()
            DebugLogger.log("AuthTokenStore: session found (expired=\(expired)) for \(identifier(for: instance))")
        } else {
            DebugLogger.log("AuthTokenStore: session found (no expiry) for \(identifier(for: instance))")
        }
        if let expiry = session.expiryDate, expiry < Date() {
            return nil
        }
        return session
    }

    private func identifier(for instance: InstanceProfile) -> UUID {
        if let tokenIdentifier = instance.tokenIdentifier, let uuid = UUID(uuidString: tokenIdentifier) {
            return uuid
        }
        return instance.id
    }

    private func persist() {
        do {
            let data = try JSONEncoder().encode(sessions)
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        } catch {
            DebugLogger.error("AuthTokenStore: failed to persist auth sessions: \(error)")
        }
    }

    private static func loadPersisted() -> [UUID: AuthSession] {
        guard let data = UserDefaults.standard.data(forKey: Self.storageKey) else {
            return [:]
        }

        do {
            return try JSONDecoder().decode([UUID: AuthSession].self, from: data)
        } catch {
            DebugLogger.error("AuthTokenStore: failed to load persisted auth sessions: \(error)")
            return [:]
        }
    }
}
