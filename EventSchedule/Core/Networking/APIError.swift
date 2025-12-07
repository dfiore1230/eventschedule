import Foundation

enum APIError: LocalizedError {
    case invalidURL
    case decodingError(Error)
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
        case .decodingError:
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
}
