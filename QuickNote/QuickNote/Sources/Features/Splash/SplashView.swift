// SplashView.swift — first-launch onboarding screen

import SwiftUI

struct SplashView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        ZStack {
            WallpaperView()

            // Center: glyph + wordmark + tagline
            VStack(spacing: 0) {
                HeroMark(size: 72, haloColor: AppColors.accentBlue, breathe: true)
                    .padding(.bottom, 24)

                Text("quicknote")
                    .font(.system(size: 30, weight: .heavy))
                    .tracking(-0.7)
                    .foregroundStyle(AppColors.primaryText)

                Text("a quieter place\nthan your own messages.")
                    .font(.system(size: 15, weight: .light))
                    .tracking(-0.1)
                    .multilineTextAlignment(.center)
                    .lineSpacing(6)
                    .foregroundStyle(AppColors.secondaryText)
                    .frame(maxWidth: 260)
                    .padding(.top, 10)
            }

            // Bottom: CTA + footer
            VStack(spacing: 18) {
                Spacer()

                GlossButton(title: "get started") {
                    withAnimation(AppAnimation.springFluid) {
                        appState.stage = .inbox
                    }
                }

                Text("private by default · no account required")
                    .font(.system(size: 12, weight: .light))
                    .foregroundStyle(AppColors.tertiaryText)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 56)
        }
    }
}
