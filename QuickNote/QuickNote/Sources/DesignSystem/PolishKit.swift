// PolishKit.swift — the Apple-quality foundation layer.
// Category tints, the unified Pill, press feedback + haptics, Dynamic-Type fonts,
// and gated Liquid Glass chrome. All new visual decisions route through here.

import SwiftUI

// MARK: - Category tints (the brand's signature wash)

/// One named, consistent set of low-opacity category washes (was the ad-hoc
/// `typeWarmthColor` at mixed opacities). Whispers, not colored cards.
public enum CategoryTint {
    /// The ambient wash applied behind a card of this type. `.clear` for plain notes.
    public static func wash(_ type: NoteType) -> Color {
        switch type {
        case .task:   return Color(red: 1.00, green: 0.82, blue: 0.45).opacity(0.07) // warm cream
        case .idea:   return Color(red: 0.70, green: 0.55, blue: 1.00).opacity(0.07) // soft lavender
        case .link:   return Color(red: 0.47, green: 0.62, blue: 0.95).opacity(0.07) // cool gray-blue
        case .voice:  return Color(red: 0.45, green: 0.58, blue: 0.45).opacity(0.07) // soft sage
        case .note, .digest: return .clear
        }
    }
}

// MARK: - Dynamic Type

/// Scales a fixed point size with Dynamic Type, relative to a text style — so the
/// app's SF sizes finally respond to the user's accessibility setting.
private struct ScaledFont: ViewModifier {
    @ScaledMetric private var size: CGFloat
    private let weight: Font.Weight
    private let italic: Bool

    init(size: CGFloat, weight: Font.Weight, relativeTo: Font.TextStyle, italic: Bool) {
        _size = ScaledMetric(wrappedValue: size, relativeTo: relativeTo)
        self.weight = weight
        self.italic = italic
    }

    func body(content: Content) -> some View {
        content.font(.system(size: size, weight: weight).italic(italic))
    }
}

public extension View {
    /// Brand font that scales with Dynamic Type. Pick `relativeTo` near the role:
    /// `.largeTitle` for display, `.body` for content, `.caption2` for micro-labels.
    func appFont(_ size: CGFloat,
                 _ weight: Font.Weight = .regular,
                 relativeTo style: Font.TextStyle = .body,
                 italic: Bool = false) -> some View {
        modifier(ScaledFont(size: size, weight: weight, relativeTo: style, italic: italic))
    }
}

// MARK: - Press feedback

/// Wallet-style compress-and-rebound on press, with optional selection haptic.
/// Apply to cards, pills, and the capture bar so the app feels responsive to touch.
private struct Pressable: ViewModifier {
    var scale: CGFloat
    var haptic: Bool
    @State private var pressed = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .scaleEffect(pressed && !reduceMotion ? scale : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: pressed)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in if !pressed { pressed = true } }
                    .onEnded { _ in pressed = false }
            )
            .sensoryFeedback(.selection, trigger: haptic ? pressed : false)
    }
}

public extension View {
    func pressable(scale: CGFloat = 0.97, haptic: Bool = false) -> some View {
        modifier(Pressable(scale: scale, haptic: haptic))
    }
}

/// Press feedback for Buttons — compress-and-rebound via `isPressed`, no extra
/// gesture (safe on cards that already own swipe/flick gestures). Keeps `.plain`
/// look. Reduce-Motion aware.
public struct PressStyle: ButtonStyle {
    public var scale: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    public init(scale: CGFloat = 0.97) { self.scale = scale }
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? scale : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.62), value: configuration.isPressed)
    }
}

// MARK: - Motion (Reduce Motion aware)

public extension View {
    /// Applies `animation` unless Reduce Motion is on, in which case motion is dropped.
    @ViewBuilder
    func motion<V: Equatable>(_ animation: Animation, value: V, reduceMotion: Bool) -> some View {
        self.animation(reduceMotion ? nil : animation, value: value)
    }
}

// MARK: - Glass chrome (gated, with fallbacks)

/// Liquid Glass for floating chrome (capture bar, toolbars). Gated to iOS 26 with a
/// `.ultraThinMaterial` fallback, and a solid surface when Reduce Transparency is on.
/// Per HIG: glass belongs to the functional layer above content — never on cards.
private struct GlassChrome: ViewModifier {
    var shape: AnyShape
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        if reduceTransparency {
            content.background(AppColors.surface, in: shape)
        } else if #available(iOS 26.0, *) {
            content.glassEffect(.regular, in: shape)
        } else {
            content
                .background(.ultraThinMaterial, in: shape)
                .overlay(shape.stroke(Color.white.opacity(0.5), lineWidth: 0.5))
        }
    }
}

public extension View {
    /// Floating-chrome glass with safe fallbacks. Pass the chrome's shape.
    func glassChrome<S: Shape>(in shape: S) -> some View {
        modifier(GlassChrome(shape: AnyShape(shape)))
    }
}

// MARK: - Unified Pill

/// The one pill used across filter rails, tag chips, type badges, and segmented
/// controls — single height, padding, radius, and pressed state. Collapses the 11
/// ad-hoc `Capsule()` implementations into one component.
public struct Pill<Content: View>: View {
    private let isActive: Bool
    private let content: Content

    public init(isActive: Bool, @ViewBuilder content: () -> Content) {
        self.isActive = isActive
        self.content = content()
    }

    public var body: some View {
        content
            .padding(.horizontal, 10)
            .frame(height: 28)
            .background(
                isActive
                    ? AnyShapeStyle(LinearGradient(colors: [AppColors.ctaTop, AppColors.ctaBottom],
                                                   startPoint: .top, endPoint: .bottom))
                    : AnyShapeStyle(AppColors.ink.opacity(0.06))
            )
            .clipShape(Capsule())
            .overlay(Capsule().stroke(AppColors.ink.opacity(isActive ? 0 : 0.05), lineWidth: 0.5))
    }
}
