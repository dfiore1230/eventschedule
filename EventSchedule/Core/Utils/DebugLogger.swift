import Foundation
import OSLog
#if canImport(Darwin)
import Darwin
#endif

enum DebugLogger {
    private static let subsystem = "com.eventschedule.app"
    private static let networkLogger = Logger(subsystem: subsystem, category: "network")
    private static let onboardingLogger = Logger(subsystem: subsystem, category: "onboarding")

    static func networkRequest(_ request: URLRequest) {
        #if DEBUG
        let method = request.httpMethod ?? "UNKNOWN"
        let urlString = request.url?.absoluteString ?? "<nil>"
        let headers = request.allHTTPHeaderFields ?? [:]
        let bodyString: String
        if let body = request.httpBody, let decoded = String(data: body, encoding: .utf8) {
            bodyString = decoded
        } else {
            bodyString = "<empty>"
        }

        networkLogger.debug("➡️ Request: \(method, privacy: .public) \(urlString, privacy: .public) headers: \(headers, privacy: .public) body: \(bodyString, privacy: .public)")
        #endif
    }

    static func networkResponse(_ response: HTTPURLResponse, data: Data) {
        #if DEBUG
        let urlString = response.url?.absoluteString ?? "<nil>"
        let bodyPreview = String(data: data, encoding: .utf8) ?? "<non-UTF8 body>"
        networkLogger.debug("⬅️ Response: \(response.statusCode, privacy: .public) for \(urlString, privacy: .public) body: \(bodyPreview, privacy: .public)")
        #endif
    }

    static func networkError(_ error: Error, request: URLRequest) {
        #if DEBUG
        let method = request.httpMethod ?? "UNKNOWN"
        let urlString = request.url?.absoluteString ?? "<nil>"
        networkLogger.error("❌ Network error for \(method, privacy: .public) \(urlString, privacy: .public): \(String(describing: error), privacy: .public)")
        #endif
    }

    static func onboarding(_ message: String) {
        #if DEBUG
        onboardingLogger.debug("🔍 \(message, privacy: .public)")
        #endif
    }

    static func breakpoint(_ reason: String? = nil) {
        #if DEBUG
        if let reason {
            onboardingLogger.debug("⛔️ Breakpoint triggered: \(reason, privacy: .public)")
        }
        #if canImport(Darwin)
        raise(SIGTRAP)
        #endif
        #endif
    }
}
