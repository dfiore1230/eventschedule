
import Foundation
import OSLog

/// Lightweight wrapper around os.Logger that also mirrors messages to the Xcode console when running
/// in Debug builds. This ensures logs are still captured on device even when print statements are
/// stripped or suppressed.
enum DebugLogger {
    private static let subsystem = "com.eventschedule.app"
    private static let generalLogger = Logger(subsystem: subsystem, category: "general")
    private static let networkLogger = Logger(subsystem: subsystem, category: "network")

    static func log(_ message: String) {
        #if DEBUG
        print(message)
        #endif
        generalLogger.debug("\(message, privacy: .public)")
    }

    static func error(_ message: String) {
        #if DEBUG
        print(message)
        #endif
        generalLogger.error("\(message, privacy: .public)")
    }

    static func network(_ message: String) {
        #if DEBUG
        print(message)
        #endif
        networkLogger.debug("\(message, privacy: .public)")
    }
}
