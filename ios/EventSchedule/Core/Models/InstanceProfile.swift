import Foundation
import SwiftUI

enum InstanceEnvironment: String, Codable, CaseIterable {
    case prod
    case staging
    case dev
}

struct InstanceProfile: Identifiable, Codable, Equatable {
    let id: UUID
    var displayName: String
    var baseURL: URL
    var environment: InstanceEnvironment
    var authMethod: AuthMethod
    var authEndpoints: [String: URL]?
    var featureFlags: [String: Bool]
    var minAppVersion: String?
    var rateLimits: [String: Int]?
    var tokenIdentifier: String?
    var theme: ThemeDTO?

    enum AuthMethod: String, Codable {
        case sanctum
        case oauth2
        case jwt
    }
}

struct ThemeDTO: Codable, Equatable {
    let primaryHex: String
    let secondaryHex: String
    let accentHex: String
    let textHex: String
    let backgroundHex: String
    let buttonRadius: CGFloat
    let legalFooter: String?

    static let `default` = ThemeDTO(
        primaryHex: "#007AFF",
        secondaryHex: "#8E8E93",
        accentHex: "#34C759",
        textHex: "#000000",
        backgroundHex: "#FFFFFF",
        buttonRadius: 10,
        legalFooter: nil
    )
}
