import Foundation
import Combine

// Local fallbacks for missing types used during legacy migration.
// If your project already defines these elsewhere, those will be used instead.
#if canImport(Foundation) // keep simple guard; avoid conflicting redefinitions
// Provide minimal RawRepresentable enums to satisfy decoding defaults.
private enum Environment: String {
    case production
}

private enum AuthMethod: String {
    case none
}
#endif

// DebugLogger mirrors output to the Xcode console even when stdout/stderr
// are not presented as a TTY (e.g., when running under the debugger).
// Using it here ensures persistence failures remain visible during debugging.

@MainActor
final class InstanceStore: ObservableObject {
    @Published private(set) var instances: [InstanceProfile] = []
    @Published var activeInstanceID: UUID?

    private let storageKey = "instances_v1"
    private let activeKey = "activeInstance_v1"

    init() {
        load()
    }

    var activeInstance: InstanceProfile? {
        guard let id = activeInstanceID else { return nil }
        return instances.first { $0.id == id }
    }

    func setInstances(_ instances: [InstanceProfile]) {
        self.instances = instances
        if activeInstance == nil {
            activeInstanceID = instances.first?.id
        }
        persist()
    }

    func addInstance(_ instance: InstanceProfile) {
        instances.append(instance)
        activeInstanceID = instance.id
        persist()
    }

    func removeInstance(_ instanceID: UUID) {
        if let instance = instances.first(where: { $0.id == instanceID }) {
            AuthTokenStore.shared.clearSession(for: instance)
        }

        instances.removeAll { $0.id == instanceID }
        if activeInstanceID == instanceID {
            activeInstanceID = instances.first?.id
        }
        persist()
    }

    func setActiveInstance(_ instanceID: UUID) {
        guard instances.contains(where: { $0.id == instanceID }) else { return }
        activeInstanceID = instanceID
        persist()
    }

    private func load() {
        let defaults = UserDefaults.standard
        if let data = defaults.data(forKey: storageKey) {
            do {
                let decoded = try JSONDecoder().decode([InstanceProfile].self, from: data)
                self.instances = decoded
            } catch {
                DebugLogger.error("InstanceStore: failed to decode instances with new schema: \(error). Attempting legacy migration…")
                struct LegacyInstanceProfile: Decodable {
                    let id: UUID
                    let displayName: String
                    let baseURL: URL
                    // Use raw storage for types that may not exist anymore to avoid Decodable failures
                    let environmentRaw: String?
                    let authMethodRaw: String?
                    let authEndpoints: Data? // unknown schema, keep as payload
                    let featureFlags: [String: Bool]?
                    let minAppVersion: String?
                    let rateLimits: Data?
                    let tokenIdentifier: String?
                    let theme: Data?

                    enum CodingKeys: String, CodingKey {
                        case id, displayName, baseURL, featureFlags, minAppVersion, tokenIdentifier
                        case environmentRaw = "environment"
                        case authMethodRaw = "authMethod"
                        case authEndpoints
                        case rateLimits
                        case theme
                    }
                }
                do {
                    let legacy = try JSONDecoder().decode([LegacyInstanceProfile].self, from: data)

                    // Helpers to infer api/web from baseURL
                    func splitAPI(from base: URL) -> (api: URL, web: URL) {
                        if base.path.lowercased().hasSuffix("/api") {
                            return (base, base.deletingLastPathComponent())
                        } else {
                            return (base.appendingPathComponent("api"), base)
                        }
                    }

                    self.instances = legacy.map { old in
                        let urls = splitAPI(from: old.baseURL)

                        return InstanceProfile(
                            id: old.id,
                            displayName: old.displayName,
                            baseURL: urls.api,
                            environment: .prod,
                            authMethod: .jwt,
                            authEndpoints: nil,
                            featureFlags: [:],
                            minAppVersion: nil,
                            rateLimits: nil,
                            tokenIdentifier: old.tokenIdentifier,
                            theme: nil
                        )
                    }
                    DebugLogger.log("InstanceStore: migrated \(self.instances.count) instance(s) from legacy schema.")
                } catch {
                    DebugLogger.error("InstanceStore: legacy migration failed: \(error)")
                }
            }
        }

        if let idString = defaults.string(forKey: activeKey),
           let id = UUID(uuidString: idString),
           instances.contains(where: { $0.id == id }) {
            activeInstanceID = id
        } else {
            activeInstanceID = instances.first?.id
        }
    }

    private func persist() {
        let defaults = UserDefaults.standard
        do {
            let data = try JSONEncoder().encode(instances)
            defaults.set(data, forKey: storageKey)
        } catch {
            DebugLogger.error("InstanceStore: failed to encode instances: \(error)")
        }

        if let id = activeInstanceID {
            defaults.set(id.uuidString, forKey: activeKey)
        } else {
            defaults.removeObject(forKey: activeKey)
        }
    }
}
