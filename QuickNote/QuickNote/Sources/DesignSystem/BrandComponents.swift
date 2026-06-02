// BrandComponents.swift — Mark glyph, HeroMark, WallpaperView

import SwiftUI

// MARK: - Mark

/// The app's brand glyph: a rounded square with a single interior diagonal.
struct MarkGlyph: View {
    var size: CGFloat = 24
    var strokeWidth: CGFloat = 1.5
    var color: Color = AppColors.primaryText

    var body: some View {
        Canvas { ctx, sz in
            let scale = sz.width / 24
            let inset = 3.5 * scale
            let rx = 5.0 * scale

            var box = Path(
                roundedRect: CGRect(x: inset, y: inset,
                                    width: sz.width - inset * 2,
                                    height: sz.height - inset * 2),
                cornerRadius: rx
            )
            ctx.stroke(box, with: .color(color),
                       style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round))

            var diag = Path()
            diag.move(to:    CGPoint(x: 3.5 * scale, y: 13.5 * scale))
            diag.addLine(to: CGPoint(x: 13.5 * scale, y:  3.5 * scale))
            ctx.stroke(diag, with: .color(color),
                       style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round))
        }
        .frame(width: size, height: size)
    }
}

// MARK: - HeroMark

/// Mark wrapped in a soft radial halo — the only place color appears.
struct HeroMark: View {
    var size: CGFloat = 64
    var haloColor: Color = AppColors.accentBlue
    var breathe: Bool = false

    @State private var animating = false

    private var ringSize: CGFloat { size * 1.7 }

    var body: some View {
        ZStack {
            // Outermost halo
            Circle()
                .fill(
                    RadialGradient(
                        colors: [haloColor.opacity(0.33), haloColor.opacity(0)],
                        center: .center,
                        startRadius: 0,
                        endRadius: ringSize / 2
                    )
                )
                .blur(radius: 8)
                .frame(width: ringSize, height: ringSize)

            // Inner brighter glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [haloColor.opacity(0.4), haloColor.opacity(0)],
                        center: .center,
                        startRadius: 0,
                        endRadius: size * 1.15 / 2
                    )
                )
                .blur(radius: 2)
                .frame(width: size * 1.15, height: size * 1.15)

            // Pillow disc
            Circle()
                .fill(
                    RadialGradient(
                        stops: [
                            .init(color: .white,                  location: 0),
                            .init(color: Color(hex: "EEF1F6"),    location: 0.7),
                            .init(color: Color(hex: "E4E8EE"),    location: 1.0),
                        ],
                        center: UnitPoint(x: 0.35, y: 0.3),
                        startRadius: 0,
                        endRadius: size * 0.95 / 2
                    )
                )
                .shadow(color: .white.opacity(0.9), radius: 0, x: 0, y: 1)
                .shadow(color: Color(hex: "3C5070").opacity(0.12), radius: 18, x: 0, y: 6)
                .frame(width: size * 0.95, height: size * 0.95)

            MarkGlyph(size: size * 0.55, strokeWidth: 1.4)
        }
        .frame(width: ringSize, height: ringSize)
        .scaleEffect(animating ? 1.06 : 1.0)
        .opacity(animating ? 1.0 : 0.95)
        .onAppear {
            guard breathe else { return }
            withAnimation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true)) {
                animating = true
            }
        }
    }
}

// MARK: - WallpaperView

/// The ambient background field — a cold off-white with soft radial tints.
struct WallpaperView: View {
    var body: some View {
        ZStack {
            AppColors.background

            RadialGradient(
                colors: [Color.dynamic(light: "D7DEE8", dark: "1B2230").opacity(0.70), .clear],
                center: UnitPoint(x: 0.30, y: 0),
                startRadius: 0,
                endRadius: 340
            )

            RadialGradient(
                colors: [Color.dynamic(light: "E1E3E8", dark: "171A22").opacity(0.60), .clear],
                center: UnitPoint(x: 0.80, y: 1),
                startRadius: 0,
                endRadius: 260
            )
        }
        .ignoresSafeArea()
    }
}
