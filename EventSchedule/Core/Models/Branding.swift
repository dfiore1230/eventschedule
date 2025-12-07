import SwiftUI

struct BrandingResponse: Codable {
    let logoURL: URL?
    let wordmarkURL: URL?
    let primaryHex: String
    let secondaryHex: String
    let accentHex: String
    let textHex: String
    let bgHex: String
    let buttonRadius: CGFloat
    let legalFooter: String?
    let appIconURL: URL?

    enum CodingKeys: String, CodingKey {
        case logoURL = "logo_url"
        case wordmarkURL = "wordmark_url"
        case primaryHex = "primary_hex"
        case secondaryHex = "secondary_hex"
        case accentHex = "accent_hex"
        case textHex = "text_hex"
        case bgHex = "bg_hex"
        case buttonRadius = "button_radius"
        case legalFooter = "legal_footer"
        case appIconURL = "app_icon_url"
    }
}

struct Theme: Equatable {
    let primary: Color
    let secondary: Color
    let accent: Color
    let text: Color
    let background: Color
    let buttonRadius: CGFloat
    let legalFooter: String?
}

extension Theme {
    static let `default` = Theme(
        primary: .blue,
        secondary: .gray,
        accent: .green,
        text: .primary,
        background: .systemBackground,
        buttonRadius: 10,
        legalFooter: nil
    )
}

extension Color {
    static var systemBackground: Color {
        Color(UIColor.systemBackground)
    }
}

extension Theme {
    init(from branding: BrandingResponse) {
        let primary = Color(hex: branding.primaryHex) ?? .blue
        let secondary = Color(hex: branding.secondaryHex) ?? .gray
        let accent = Color(hex: branding.accentHex) ?? .green
        let text = Color(hex: branding.textHex) ?? .primary
        let background = Color(hex: branding.bgHex) ?? .systemBackground

        self.init(
            primary: primary,
            secondary: secondary,
            accent: accent,
            text: text,
            background: background,
            buttonRadius: branding.buttonRadius,
            legalFooter: branding.legalFooter
        )
    }
}
