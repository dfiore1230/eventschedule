import Foundation
import Combine

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
            print("Failed to persist auth sessions: \(error)")
        }
    }

    private static func loadPersisted() -> [UUID: AuthSession] {
        guard let data = UserDefaults.standard.data(forKey: Self.storageKey) else {
            return [:]
        }

        do {
            return try JSONDecoder().decode([UUID: AuthSession].self, from: data)
        } catch {
            print("Failed to load persisted auth sessions: \(error)")
            return [:]
        }
    }
}
