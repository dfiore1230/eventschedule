
import Foundation
import OSLog
import Darwin

/// Lightweight wrapper around os.Logger that also mirrors messages to the Xcode console when running
/// in Debug builds. This ensures logs are still captured on device even when print statements are
/// stripped or suppressed.
enum DebugLogger {
    private static let subsystem = "com.eventschedule.app"
    private static let generalLogger = Logger(subsystem: subsystem, category: "general")
    private static let networkLogger = Logger(subsystem: subsystem, category: "network")

    private static var isDebuggerAttached: Bool {
        // When running from Xcode the standard error stream is attached to the
        // debug console, so we can check for a TTY to determine if we should
        // mirror messages there.
        isatty(STDERR_FILENO) != 0
    }

    private static func mirrorToXcodeConsole(_ message: String) {
        guard isDebuggerAttached else { return }
        fputs("[EventSchedule] \(message)\n", stderr)
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
