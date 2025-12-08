import Foundation

enum APIError: LocalizedError, Equatable {
    case invalidURL
    case decodingError(Error, bodyPreview: String?)
    case encodingError(Error)
    case networkError(Error)
    case serverError(statusCode: Int, message: String?)
    case unauthorized
    case forbidden
    case rateLimited(retryAfter: TimeInterval?)
    case unknown

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid server URL."
        case .decodingError(_, let bodyPreview):
            if let bodyPreview, !bodyPreview.isEmpty {
                return "Unexpected response from server: \(bodyPreview)"
            }
            return "Unexpected response from server."
        case .encodingError:
            return "Failed to encode request."
        case .networkError(let error):
            return error.localizedDescription
        case .serverError(_, let message):
            return message ?? "Server returned an error."
        case .unauthorized:
            return "You are not authorized. Please log in again."
        case .forbidden:
            return "You don't have permission to perform this action."
        case .rateLimited:
            return "Too many requests. Please try again in a moment."
        case .unknown:
            return "An unknown error occurred."
        }
    }

    static func == (lhs: APIError, rhs: APIError) -> Bool {
        switch (lhs, rhs) {
        case (.invalidURL, .invalidURL),
             (.unauthorized, .unauthorized),
             (.forbidden, .forbidden),
             (.unknown, .unknown):
            return true

        case let (.serverError(statusA, messageA), .serverError(statusB, messageB)):
            return statusA == statusB && messageA == messageB

        case let (.rateLimited(retryA), .rateLimited(retryB)):
            return retryA == retryB

        case let (.decodingError(errorA, bodyA), .decodingError(errorB, bodyB)):
            return (errorA as NSError) == (errorB as NSError) && bodyA == bodyB

        case let (.encodingError(errorA), .encodingError(errorB)),
             let (.networkError(errorA), .networkError(errorB)):
            return (errorA as NSError) == (errorB as NSError)

        default:
            return false
        }
    }
}
