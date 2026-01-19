import Foundation

/// Centralized instrumentation helper to trace user interactions around
/// the event lifecycle (creation, update, display). This keeps log
/// formats consistent so we can aggregate them when diagnosing issues.
enum EventInstrumentation {
    static func log(
        action: String,
        eventId: String? = nil,
        eventName: String? = nil,
        instance: InstanceProfile? = nil,
        metadata: [String: String] = [:]
    ) {
        let message = formattedMessage(
            level: "INFO",
            action: action,
            eventId: eventId,
            eventName: eventName,
            instance: instance,
            metadata: metadata
        )
        DebugLogger.log(message)
    }

    static func error(
        action: String,
        eventId: String? = nil,
        eventName: String? = nil,
        instance: InstanceProfile? = nil,
        error: Error,
        metadata: [String: String] = [:]
    ) {
        var extendedMetadata = metadata
        extendedMetadata["error"] = error.localizedDescription
        let message = formattedMessage(
            level: "ERROR",
            action: action,
            eventId: eventId,
            eventName: eventName,
            instance: instance,
            metadata: extendedMetadata
        )
        DebugLogger.error(message)
    }

    private static func formattedMessage(
        level: String,
        action: String,
        eventId: String?,
        eventName: String?,
        instance: InstanceProfile?,
        metadata: [String: String]
    ) -> String {
        var components: [String] = ["level=\(level)", "action=\(action)"]
        if let eventId { components.append("eventId=\(eventId)") }
        if let eventName, !eventName.isEmpty { components.append("eventName=\(eventName)") }
        if let instance {
            components.append("instanceName=\(instance.displayName)")
            components.append("instanceId=\(instance.id)")
        }
        if !metadata.isEmpty {
            let meta = metadata
                .sorted { $0.key < $1.key }
                .map { "\($0)=\($1)" }
                .joined(separator: ",")
            components.append("metadata={\(meta)}")
        }
        return "EventInstrumentation | " + components.joined(separator: " | ")
    }
}
