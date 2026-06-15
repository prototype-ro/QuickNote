//
//  Theme.swift
//  QuickNote
//

import SwiftUI
import UIKit

// MARK: - Appearance

/// User's appearance preference. `.system` follows the device setting.
public enum AppearanceMode: String, CaseIterable {
    case system, light, dark

    public var label: String {
        switch self {
        case .system: return "system"
        case .light:  return "light"
        case .dark:   return "dark"
        }
    }

    public var icon: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light:  return "sun.max"
        case .dark:   return "moon"
        }
    }

    /// The SwiftUI scheme to force, or `nil` to follow the system.
    public var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }
}

// MARK: - Colors

public enum AppColors {
    // Base Canvas — adaptive
    public static let background = Color.dynamic(light: "F0F2F4", dark: "0E0F12")
    public static let surface = Color.dynamic(light: "FFFFFF", dark: "1B1D21")
    public static let overlay = background.opacity(0.80)

    // Typography — adaptive
    public static let primaryText = Color.dynamic(light: "0A0A0B", dark: "F2F3F5")
    public static let secondaryText = Color.dynamic(light: "6B7280", dark: "9BA1AC")
    public static let tertiaryText = Color.dynamic(light: "9CA3AF", dark: "6C727C")

    /// Adaptive "ink" — near-black in light, near-white in dark. Used for text,
    /// subtle opacity fills, and hairline borders alike (so `.opacity(x)` flips
    /// correctly in both schemes). Replaces the old hardcoded `Color(hex: "0A0A0B")`.
    public static let ink = primaryText
    /// Adaptive divider/hairline (was `E5E7EB`).
    public static let hairline = Color.dynamic(light: "E5E7EB", dark: "2A2D33")
    /// Dimming scrim behind modal sheets — stays dark in BOTH schemes (a scrim
    /// darkens; it must not flip to white in dark mode like `ink` would).
    public static let scrim = Color.dynamic(light: "0A0A0B", dark: "000000")

    // Accent / CTA — adaptive so dark buttons invert to light in dark mode
    public static let accent = Color.dynamic(light: "0A0A0B", dark: "F2F3F5")
    /// Foreground placed on `accent` / CTA gradients (white in light, dark in dark).
    public static let onAccent = Color.dynamic(light: "FFFFFF", dark: "0A0A0B")
    /// CTA gradient endpoints (filter chip / send button / etc).
    public static let ctaTop = Color.dynamic(light: "1a1a1d", dark: "FFFFFF")
    public static let ctaBottom = Color.dynamic(light: "000000", dark: "E4E6EA")

    public static let accentBlue = Color(hex: "7AA7FF")      // halo, library badge
    public static let accentSage = Color(hex: "9BC4A8")
    /// Voice category — soft sage. Whisper wash on cards, accent on controls.
    /// Deeper in light for text contrast; lifts in dark. Adaptive via hex `dynamic`.
    public static let voiceAccent = Color.dynamic(light: "739473", dark: "9EBD9E")
    public static let accentAmber = Color(hex: "E8B26A")
    public static let accentRose = Color(hex: "E59AAA")
    public static let accentViolet = Color(hex: "A89BD8")
    public static let accentSlate = Color(hex: "9AA4B2")
    public static let accentSoft = hairline
    public static let destructive = Color(hex: "EF4444")     // delete red (DESIGN.md)

    // Chip states
    public static let chipInactiveBackground = ink.opacity(0.06)
    public static let chipActiveBackground = accent
    public static let chipInactiveText = secondaryText
    public static let chipActiveText = onAccent

    // Note type badge backgrounds (tinted glass)
    public static func badgeBackground(for type: NoteType) -> Color {
        switch type {
        case .task:   return ink.opacity(0.08)
        case .idea:   return ink.opacity(0.06)
        case .note:   return ink.opacity(0.05)
        case .link:   return ink.opacity(0.07)
        case .digest: return ink.opacity(0.04)
        case .voice:  return ink.opacity(0.05)
        }
    }
}

// MARK: - Typography

public enum AppTypography {
    // Hero / Screen title: 34pt weight 800 tracking -0.5
    public static func hero(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 34, weight: .heavy))
            .tracking(-0.5)
            .foregroundStyle(AppColors.primaryText)
    }

    // Section heading: 22pt weight 700 tracking -0.3
    public static func sectionHeading(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 22, weight: .bold))
            .tracking(-0.3)
            .foregroundStyle(AppColors.primaryText)
    }

    // Card title: 17pt weight 600 tracking -0.2
    public static func cardTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 17, weight: .semibold))
            .tracking(-0.2)
            .foregroundStyle(AppColors.primaryText)
    }

    // Body: 15pt weight 300 tracking 0.0 leading 1.5
    public static func body(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 15, weight: .light))
            .lineSpacing(15 * 0.5)
            .foregroundStyle(AppColors.primaryText)
    }

    // Caption / Meta: 13pt weight 400 tracking 0.1
    public static func caption(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .regular))
            .tracking(0.1)
            .foregroundStyle(AppColors.secondaryText)
    }

    // Micro / Badge: 11pt weight 500 tracking 0.3 uppercase
    public static func micro(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .medium))
            .tracking(0.3)
            .foregroundStyle(AppColors.primaryText)
    }
}

// MARK: - Spacing

public enum AppSpacing {
    public static let xxs: CGFloat = 4
    public static let xs: CGFloat = 8
    public static let sm: CGFloat = 12
    public static let md: CGFloat = 16
    public static let lg: CGFloat = 20
    public static let xl: CGFloat = 24
    public static let xxl: CGFloat = 32
    public static let screenTop: CGFloat = 48

    public static let cardPaddingH: CGFloat = 16
    public static let cardPaddingV: CGFloat = 14
    public static let cardSpacing: CGFloat = 10
    public static let screenPaddingH: CGFloat = 20
}

// MARK: - Corner Radius

public enum AppRadius {
    public static let card: CGFloat = 16
    public static let cardLarge: CGFloat = 20
    public static let button: CGFloat = 14
    public static let captureBar: CGFloat = 18
    public static let pill: CGFloat = 999
}

// MARK: - Animations

public enum AppAnimation {
    public static let springSnappy = Animation.spring(response: 0.3, dampingFraction: 0.7)
    public static let springFluid = Animation.spring(response: 0.5, dampingFraction: 0.8)
    public static let springGentle = Animation.spring(response: 0.6, dampingFraction: 0.9)
}

// MARK: - Component Heights

public enum AppSize {
    public static let chipHeight: CGFloat = 28
    public static let buttonHeight: CGFloat = 52
    public static let captureBarMin: CGFloat = 48
    public static let captureBarMax: CGFloat = 120
    public static let sendButtonSize: CGFloat = 32
    public static let navBarHeight: CGFloat = 44
}

// MARK: - View Modifiers

public struct FrostedCardStyle: ViewModifier {
    public func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.card)
                    .stroke(Color.white.opacity(0.6), lineWidth: 0.5)
            )
    }
}

public struct CaptureBarStyle: ViewModifier {
    public func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.captureBar))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.captureBar)
                    .stroke(Color.white.opacity(0.5), lineWidth: 0.5)
            )
    }
}

public extension View {
    func frostedCard() -> some View {
        modifier(FrostedCardStyle())
    }

    func captureBarStyle() -> some View {
        modifier(CaptureBarStyle())
    }
}

// MARK: - Color Extension

extension Color {
    /// A color that resolves to `light` or `dark` based on the active interface
    /// style — the foundation of the app's adaptive theming.
    static func dynamic(light: String, dark: String) -> Color {
        Color(uiColor: UIColor { traits in
            UIColor(Color(hex: traits.userInterfaceStyle == .dark ? dark : light))
        })
    }

    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
