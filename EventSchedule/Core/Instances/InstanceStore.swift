import Foundation
import Combine

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
                DebugLogger.error("InstanceStore: failed to decode instances: \(error)")
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
