import SwiftUI

// MARK: - Glass Panel Modifier

struct GlassPanelModifier: ViewModifier {
    @Environment(\.colorScheme) private var scheme
    var cornerRadius: CGFloat = 16
    var borderOpacity: Double = 0.05
    
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .fill(AppTheme.glassBackground(scheme))
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(
                        scheme == .dark
                            ? Color.white.opacity(borderOpacity)
                            : Color.black.opacity(borderOpacity),
                        lineWidth: 1
                    )
            )
    }
}

// MARK: - Liquid Gradient Background

struct LiquidGradientBackground: View {
    @Environment(\.colorScheme) private var scheme
    var intensity: Double = 0.40
    
    var body: some View {
        if scheme == .dark {
            ZStack {
                AppTheme.background(.dark)
                
                RadialGradient(
                    colors: [Color(hex: 0x380052).opacity(intensity), .clear],
                    center: .topLeading,
                    startRadius: 0,
                    endRadius: UIBounds.width * 0.7
                )
                
                RadialGradient(
                    colors: [Color(hex: 0x002C65).opacity(intensity), .clear],
                    center: .bottomTrailing,
                    startRadius: 0,
                    endRadius: UIBounds.width * 0.7
                )
            }
            .ignoresSafeArea()
        } else {
            AppTheme.background(.light)
                .ignoresSafeArea()
        }
    }
}

// MARK: - Hero Scrim Gradient

struct HeroScrimModifier: ViewModifier {
    @Environment(\.colorScheme) private var scheme
    var alignment: Alignment = .bottom
    
    func body(content: Content) -> some View {
        content.overlay(alignment: alignment) {
            LinearGradient(
                colors: [
                    AppTheme.background(scheme),
                    AppTheme.background(scheme).opacity(0.6),
                    .clear
                ],
                startPoint: .bottom,
                endPoint: .top
            )
        }
    }
}

// MARK: - Glow Shadow Modifier

struct GlowShadowModifier: ViewModifier {
    var color: Color = AppTheme.primary
    var radius: CGFloat = 20
    var opacity: Double = 0.4
    
    func body(content: Content) -> some View {
        content
            .shadow(color: color.opacity(opacity), radius: radius)
    }
}

// MARK: - Active Glow Border

struct ActiveGlowBorderModifier: ViewModifier {
    var isActive: Bool
    var color: Color = AppTheme.primary
    var cornerRadius: CGFloat = 16
    
    func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(
                        isActive ? color.opacity(0.40) : .clear,
                        lineWidth: isActive ? 2 : 0
                    )
            )
            .shadow(
                color: isActive ? color.opacity(0.30) : .clear,
                radius: isActive ? 15 : 0
            )
    }
}

// MARK: - Progress Bar with Glow

struct GlowProgressBar: View {
    var progress: Double
    var height: CGFloat = 3
    var trackColor: Color = AppTheme.progressTrack
    var barColor: Color = AppTheme.primary
    
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(trackColor)
                
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(
                        LinearGradient(
                            colors: [AppTheme.primaryDim, barColor],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geo.size.width * min(max(progress, 0), 1))
                    .shadow(color: barColor.opacity(0.80), radius: 4)
            }
        }
        .frame(height: height)
    }
}

// MARK: - Live Pulse Indicator

struct LivePulseIndicator: View {
    @State private var isPulsing = false
    var size: CGFloat = 6
    
    var body: some View {
        Circle()
            .fill(AppTheme.error)
            .frame(width: size, height: size)
            .scaleEffect(isPulsing ? 1.3 : 1.0)
            .opacity(isPulsing ? 0.7 : 1.0)
            .animation(
                .easeInOut(duration: 0.8).repeatForever(autoreverses: true),
                value: isPulsing
            )
            .onAppear { isPulsing = true }
    }
}

// MARK: - Live Badge

struct LiveBadge: View {
    var body: some View {
        HStack(spacing: 4) {
            LivePulseIndicator(size: 5)
            Text("LIVE")
                .font(.system(size: 9, weight: .heavy))
                .tracking(0.8)
        }
        .foregroundColor(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(AppTheme.errorContainer, in: Capsule())
    }
}

// MARK: - Pill Button Styles

struct PrimaryPillButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .bold))
            .foregroundColor(AppTheme.onPrimaryContainer)
            .padding(.horizontal, 24)
            .padding(.vertical, 10)
            .background(AppTheme.primary, in: Capsule())
            .shadow(color: AppTheme.primary.opacity(0.40), radius: 10)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct GlassPillButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var scheme
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(AppTheme.onSurface(scheme))
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - View Extensions

extension View {
    func glassPanel(cornerRadius: CGFloat = 16, borderOpacity: Double = 0.05) -> some View {
        modifier(GlassPanelModifier(cornerRadius: cornerRadius, borderOpacity: borderOpacity))
    }
    
    func heroScrim(alignment: Alignment = .bottom) -> some View {
        modifier(HeroScrimModifier(alignment: alignment))
    }
    
    func glowShadow(color: Color = AppTheme.primary, radius: CGFloat = 20, opacity: Double = 0.4) -> some View {
        modifier(GlowShadowModifier(color: color, radius: radius, opacity: opacity))
    }
    
    func activeGlow(isActive: Bool, color: Color = AppTheme.primary, cornerRadius: CGFloat = 16) -> some View {
        modifier(ActiveGlowBorderModifier(isActive: isActive, color: color, cornerRadius: cornerRadius))
    }
}

// MARK: - Screen Bounds Helper

private enum UIBounds {
    static var width: CGFloat {
        #if os(macOS)
        return NSScreen.main?.frame.width ?? 1440
        #elseif os(tvOS)
        return 1920
        #else
        return UIScreen.main.bounds.width
        #endif
    }
}
