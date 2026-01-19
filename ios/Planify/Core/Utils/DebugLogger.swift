
import Foundation
import OSLog
import Darwin

/// Lightweight wrapper around os.Logger that also mirrors messages to the Xcode console when running
/// in Debug builds. This ensures logs are still captured on device even when print statements are
/// stripped or suppressed.
enum DebugLogger {
    private static let subsystem = "com.planify.app"
    private static let generalLogger = Logger(subsystem: subsystem, category: "general")
    private static let networkLogger = Logger(subsystem: subsystem, category: "network")

    private static func mirrorToXcodeConsole(_ message: String) {
        // Xcode 15+ no longer exposes the debug console as a TTY, which caused
        // the previous detection using `isatty` to suppress all mirrored
        // messages. Writing directly to stderr keeps the console output visible
        // even in Release builds, which is helpful when debugging on device or
        // with TestFlight installs.
        fputs("[Planify] \(message)\n", stderr)
    }

    static func log(_ message: String) {
        mirrorToXcodeConsole(message)
        generalLogger.debug("\(message, privacy: .public)")
    }

    static func error(_ message: String) {
        mirrorToXcodeConsole(message)
        generalLogger.error("\(message, privacy: .public)")
    }

    static func network(_ message: String) {
        mirrorToXcodeConsole(message)
        networkLogger.debug("\(message, privacy: .public)")
    }
}
