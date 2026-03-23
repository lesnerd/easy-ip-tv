import SwiftUI

/// Semantic typography scale for the Liquid Glass design system.
/// Uses SF Pro (system font) with weight/size tiers that match the mockup's
/// Manrope (headlines) and Inter (body) pairing.
enum AppTypography {
    
    // MARK: - Headlines (bold/extrabold, larger sizes)
    
    static var heroTitle: Font {
        #if os(tvOS)
        return .system(size: 56, weight: .heavy, design: .rounded)
        #elseif os(macOS)
        return .system(size: 48, weight: .heavy, design: .rounded)
        #else
        return .system(size: 36, weight: .heavy, design: .rounded)
        #endif
    }
    
    static var screenTitle: Font {
        #if os(tvOS)
        return .system(size: 32, weight: .bold, design: .rounded)
        #elseif os(macOS)
        return .system(size: 28, weight: .bold, design: .rounded)
        #else
        return .system(size: 22, weight: .bold, design: .rounded)
        #endif
    }
    
    static var sectionTitle: Font {
        #if os(tvOS)
        return .system(size: 24, weight: .bold, design: .rounded)
        #elseif os(macOS)
        return .system(size: 20, weight: .bold, design: .rounded)
        #else
        return .system(size: 18, weight: .bold, design: .rounded)
        #endif
    }
    
    static var cardTitle: Font {
        #if os(tvOS)
        return .system(size: 18, weight: .bold)
        #elseif os(macOS)
        return .system(size: 15, weight: .bold)
        #else
        return .system(size: 14, weight: .bold)
        #endif
    }
    
    // MARK: - Body Text
    
    static var bodyLarge: Font {
        #if os(tvOS)
        return .system(size: 20, weight: .regular)
        #elseif os(macOS)
        return .system(size: 16, weight: .regular)
        #else
        return .system(size: 15, weight: .regular)
        #endif
    }
    
    static var body: Font {
        #if os(tvOS)
        return .system(size: 18, weight: .regular)
        #elseif os(macOS)
        return .system(size: 14, weight: .regular)
        #else
        return .system(size: 13, weight: .regular)
        #endif
    }
    
    static var bodyMedium: Font {
        #if os(tvOS)
        return .system(size: 18, weight: .medium)
        #elseif os(macOS)
        return .system(size: 14, weight: .medium)
        #else
        return .system(size: 13, weight: .medium)
        #endif
    }
    
    // MARK: - Labels & Captions
    
    static var label: Font {
        #if os(tvOS)
        return .system(size: 14, weight: .semibold)
        #elseif os(macOS)
        return .system(size: 12, weight: .semibold)
        #else
        return .system(size: 11, weight: .semibold)
        #endif
    }
    
    static var caption: Font {
        #if os(tvOS)
        return .system(size: 13, weight: .medium)
        #elseif os(macOS)
        return .system(size: 11, weight: .medium)
        #else
        return .system(size: 10, weight: .medium)
        #endif
    }
    
    static var micro: Font {
        #if os(tvOS)
        return .system(size: 11, weight: .bold)
        #elseif os(macOS)
        return .system(size: 9, weight: .bold)
        #else
        return .system(size: 9, weight: .bold)
        #endif
    }
    
    // MARK: - Tab & Nav Labels
    
    static var tabLabel: Font {
        .system(size: 10, weight: .medium)
    }
    
    static var sidebarItem: Font {
        #if os(tvOS)
        return .system(size: 16, weight: .semibold)
        #else
        return .system(size: 14, weight: .semibold)
        #endif
    }
    
    // MARK: - Badge & Tag
    
    static var badge: Font {
        .system(size: 10, weight: .heavy)
    }
    
    static var tagLabel: Font {
        .system(size: 10, weight: .bold)
    }
    
    // MARK: - Tracking Presets
    
    static let wideTracking: CGFloat = 0.2
    static let extraWideTracking: CGFloat = 0.05
}
