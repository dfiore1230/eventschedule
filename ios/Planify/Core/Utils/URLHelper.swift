import Foundation

extension String {
    /// Converts a relative URL path to an absolute URL using the provided base URL
    /// If the string is already an absolute URL, returns it unchanged
    func toAbsoluteURL(baseURL: URL) -> String {
        // If already absolute, return as-is
        if self.hasPrefix("http://") || self.hasPrefix("https://") {
            return self
        }
        
        // Remove /api from base URL if present
        var baseURLString = baseURL.absoluteString
        if baseURLString.hasSuffix("/api") {
            baseURLString = String(baseURLString.dropLast(4))
        }
        if baseURLString.hasSuffix("/") {
            baseURLString = String(baseURLString.dropLast())
        }
        
        // Ensure relative path starts with /
        let path = self.hasPrefix("/") ? self : "/" + self
        return baseURLString + path
    }
}

extension Optional where Wrapped == String {
    /// Converts an optional relative URL path to an absolute URL
    func toAbsoluteURL(baseURL: URL) -> String? {
        guard let self = self else { return nil }
        return self.toAbsoluteURL(baseURL: baseURL)
    }
}
