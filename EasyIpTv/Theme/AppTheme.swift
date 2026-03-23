import SwiftUI

/// Liquid Glass design system color palette.
/// All colors adapt automatically to light/dark mode via `colorScheme`.
enum AppTheme {
    
    // MARK: - Backgrounds & Surfaces
    
    static func background(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: 0x0E0E10) : Color(hex: 0xF8F8FA)
    }
    
    static func surface(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: 0x0E0E10) : Color(hex: 0xFFFFFF)
    }
    
    static func surfaceContainer(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: 0x19191C) : Color(hex: 0xF0F0F3)
    }
    
    static func surfaceContainerLow(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: 0x131315) : Color(hex: 0xF5F5F7)
    }
    
    static func surfaceContainerHigh(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: 0x1F1F22) : Color(hex: 0xE8E8EB)
    }
    
    static func surfaceContainerHighest(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: 0x252528) : Color(hex: 0xE0E0E3)
    }
    
    static func surfaceBright(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: 0x2C2C2F) : Color(hex: 0xFFFFFF)
    }
    
    // MARK: - Primary (Blue)
    
    static let primary = Color(hex: 0x85ADFF)
    static let primaryDim = Color(hex: 0x0070EB)
    static let primaryContainer = Color(hex: 0x6C9FFF)
    static let primaryFixed = Color(hex: 0x6C9FFF)
    static let primaryFixedDim = Color(hex: 0x5191FF)
    
    static func onPrimary(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: 0x002C65) : Color(hex: 0xFFFFFF)
    }
    
    static let onPrimaryContainer = Color(hex: 0x00214F)
    
    // MARK: - Secondary (Purple)
    
    static let secondary = Color(hex: 0xD277FF)
    static let secondaryDim = Color(hex: 0xD277FF)
    static let secondaryContainer = Color(hex: 0x7D01B1)
    
    static func onSecondary(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: 0x380052) : Color(hex: 0xFFFFFF)
    }
    
    static let onSecondaryContainer = Color(hex: 0xF3CFFF)
    
    // MARK: - Tertiary (Red/Pink)
    
    static let tertiary = Color(hex: 0xFF6E80)
    static let tertiaryDim = Color(hex: 0xE21D4D)
    static let tertiaryContainer = Color(hex: 0xFC345D)
    
    static func onTertiary(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: 0x490011) : Color(hex: 0xFFFFFF)
    }
    
    // MARK: - Error
    
    static let error = Color(hex: 0xFF716C)
    static let errorContainer = Color(hex: 0x9F0519)
    static let onErrorContainer = Color(hex: 0xFFA8A3)
    
    // MARK: - Text & Content
    
    static func onSurface(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: 0xFEFBFE) : Color(hex: 0x1A1A1C)
    }
    
    static func onSurfaceVariant(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: 0xACAAAD) : Color(hex: 0x5A585B)
    }
    
    static func onBackground(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: 0xFEFBFE) : Color(hex: 0x1A1A1C)
    }
    
    // MARK: - Outlines
    
    static func outline(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: 0x767577) : Color(hex: 0x9A989B)
    }
    
    static func outlineVariant(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: 0x48474A) : Color(hex: 0xCCCACD)
    }
    
    // MARK: - Inverse
    
    static func inverseSurface(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: 0xFCF8FB) : Color(hex: 0x2C2C2F)
    }
    
    static let inversePrimary = Color(hex: 0x005BC2)
    
    // MARK: - Glass & Transparency
    
    static func glassBackground(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color.white.opacity(0.03)
            : Color.black.opacity(0.03)
    }
    
    static func glassBorder(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color.white.opacity(0.05)
            : Color.black.opacity(0.08)
    }
    
    static func glassBorderHover(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color.white.opacity(0.10)
            : Color.black.opacity(0.12)
    }
    
    // MARK: - Semantic Aliases
    
    static let liveBadge = errorContainer
    static let liveBadgeText = onErrorContainer
    static let catchupBadge = Color.orange
    static let favoriteBadge = tertiary
    
    static func cardBackground(_ scheme: ColorScheme) -> Color {
        surfaceContainerLow(scheme)
    }
    
    static func navBarBackground(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(hex: 0x0A0A0B).opacity(0.60)
            : Color(hex: 0xF5F5F7).opacity(0.80)
    }
    
    static func tabBarBackground(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(hex: 0x1A1A1E).opacity(0.35)
            : Color(hex: 0xF5F5F7).opacity(0.40)
    }
    
    static func sidebarBackground(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(hex: 0x0A0A0C).opacity(0.60)
            : Color(hex: 0xF2F2F5).opacity(0.80)
    }
    
    static func activeTabBackground(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? primary.opacity(0.20)
            : primary.opacity(0.12)
    }
    
    static func activeTabText(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: 0x6C9FFF) : primaryDim
    }
    
    static func inactiveTabText(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(hex: 0x6B6B6E)
            : Color(hex: 0x8A8A8D)
    }
    
    // MARK: - Progress & Glow
    
    static let progressGlow = primary.opacity(0.80)
    static let progressTrack = Color.white.opacity(0.10)
    
    static func progressTrackAdaptive(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color.white.opacity(0.10)
            : Color.black.opacity(0.08)
    }
}

// MARK: - Color Hex Initializer

extension Color {
    init(hex: UInt, alpha: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: alpha
        )
    }
}
