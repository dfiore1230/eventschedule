import SwiftUI

struct BrandingResponse: Codable {
    let logoURL: URL?
    let wordmarkURL: URL?
    let primaryHex: String?
    let secondaryHex: String?
    let accentHex: String?
    let textHex: String?
    let bgHex: String?
    let buttonRadius: CGFloat?
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

    private enum ModernCodingKeys: String, CodingKey {
        case logoURL = "logoUrl"
        case wordmarkURL = "wordmarkUrl"
        case colors
        case legalFooter
        case appIconURL = "appIconUrl"
        case buttonRadius
    }

    private struct ColorsResponse: Codable {
        let primary: String?
        let secondary: String?
        let tertiary: String?
        let onPrimary: String?
        let onSecondary: String?
        let onTertiary: String?
        let background: String?
        let text: String?
    }

    init(from decoder: Decoder) throws {
        let defaultTheme = ThemeDTO.default

        let legacyContainer = try decoder.container(keyedBy: CodingKeys.self)
        if legacyContainer.contains(.primaryHex) || legacyContainer.contains(.secondaryHex) || legacyContainer.contains(.accentHex) {
            logoURL = try legacyContainer.decodeIfPresent(URL.self, forKey: .logoURL)
            wordmarkURL = try legacyContainer.decodeIfPresent(URL.self, forKey: .wordmarkURL)
            primaryHex = try legacyContainer.decodeIfPresent(String.self, forKey: .primaryHex) ?? defaultTheme.primaryHex
            secondaryHex = try legacyContainer.decodeIfPresent(String.self, forKey: .secondaryHex) ?? defaultTheme.secondaryHex
            accentHex = try legacyContainer.decodeIfPresent(String.self, forKey: .accentHex) ?? defaultTheme.accentHex
            textHex = try legacyContainer.decodeIfPresent(String.self, forKey: .textHex) ?? defaultTheme.textHex
            bgHex = try legacyContainer.decodeIfPresent(String.self, forKey: .bgHex) ?? defaultTheme.backgroundHex
            buttonRadius = try legacyContainer.decodeIfPresent(CGFloat.self, forKey: .buttonRadius) ?? defaultTheme.buttonRadius
            legalFooter = try legacyContainer.decodeIfPresent(String.self, forKey: .legalFooter)
            appIconURL = try legacyContainer.decodeIfPresent(URL.self, forKey: .appIconURL)
            return
        }

        let modernContainer = try decoder.container(keyedBy: ModernCodingKeys.self)
        let colors = try modernContainer.decodeIfPresent(ColorsResponse.self, forKey: .colors)

        logoURL = try modernContainer.decodeIfPresent(URL.self, forKey: .logoURL)
        wordmarkURL = try modernContainer.decodeIfPresent(URL.self, forKey: .wordmarkURL)
        primaryHex = colors?.primary ?? defaultTheme.primaryHex
        secondaryHex = colors?.secondary ?? primaryHex
        accentHex = colors?.tertiary ?? secondaryHex
        textHex = colors?.text ?? colors?.onPrimary ?? defaultTheme.textHex
        bgHex = colors?.background ?? defaultTheme.backgroundHex
        buttonRadius = try modernContainer.decodeIfPresent(CGFloat.self, forKey: .buttonRadius) ?? defaultTheme.buttonRadius
        legalFooter = try modernContainer.decodeIfPresent(String.self, forKey: .legalFooter)
        appIconURL = try modernContainer.decodeIfPresent(URL.self, forKey: .appIconURL)
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
        let primary = Color(hex: branding.primaryHex ?? "") ?? .blue
        let secondary = Color(hex: branding.secondaryHex ?? "") ?? .gray
        let accent = Color(hex: branding.accentHex ?? "") ?? .green
        let text = Color(hex: branding.textHex ?? "") ?? .primary
        let background = Color(hex: branding.bgHex ?? "") ?? .systemBackground
        let radius = branding.buttonRadius ?? 10

        self.init(
            primary: primary,
            secondary: secondary,
            accent: accent,
            text: text,
            background: background,
            buttonRadius: radius,
            legalFooter: branding.legalFooter
        )
    }

    init(dto: ThemeDTO?) {
        guard let dto else {
            self = .default
            return
        }

        let defaultTheme = Theme.default

        let primary = Color(hex: dto.primaryHex) ?? defaultTheme.primary
        let secondary = Color(hex: dto.secondaryHex) ?? defaultTheme.secondary
        let accent = Color(hex: dto.accentHex) ?? defaultTheme.accent
        let text = Color(hex: dto.textHex) ?? defaultTheme.text
        let background = Color(hex: dto.backgroundHex) ?? defaultTheme.background

        self.init(
            primary: primary,
            secondary: secondary,
            accent: accent,
            text: text,
            background: background,
            buttonRadius: dto.buttonRadius,
            legalFooter: dto.legalFooter
        )
    }
}

extension ThemeDTO {
    init(from branding: BrandingResponse) {
        self.init(
            primaryHex: branding.primaryHex ?? ThemeDTO.default.primaryHex,
            secondaryHex: branding.secondaryHex ?? (branding.primaryHex ?? ThemeDTO.default.secondaryHex),
            accentHex: branding.accentHex ?? (branding.secondaryHex ?? ThemeDTO.default.accentHex),
            textHex: branding.textHex ?? ThemeDTO.default.textHex,
            backgroundHex: branding.bgHex ?? ThemeDTO.default.backgroundHex,
            buttonRadius: branding.buttonRadius ?? ThemeDTO.default.buttonRadius,
            legalFooter: branding.legalFooter
        )
    }
}
