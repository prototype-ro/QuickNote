// SplashView.swift — first-launch onboarding screen

import SwiftUI

struct SplashView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            WallpaperView()

            VStack(spacing: 0) {
                HeroMark(size: 72, haloColor: AppColors.accentBlue, breathe: !reduceMotion)
                    .padding(.bottom, 24)
                    .accessibilityHidden(true)

                Text("quicknote")
                    .appFont(30, .heavy, relativeTo: .largeTitle)
                    .tracking(-0.7)
                    .foregroundStyle(AppColors.primaryText)

                Text("a quieter place\nthan your own messages.")
                    .appFont(15, .light, relativeTo: .body)
                    .tracking(-0.1)
                    .multilineTextAlignment(.center)
                    .lineSpacing(6)
                    .foregroundStyle(AppColors.secondaryText)
                    .frame(maxWidth: 260)
                    .padding(.top, 10)
            }
            .accessibilityElement(children: .combine)

            VStack(spacing: 18) {
                Spacer()

                GlossButton(title: "get started") {
                    UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
                    withAnimation(reduceMotion ? .easeOut(duration: 0.2) : AppAnimation.springFluid) {
                        appState.stage = .inbox
                    }
                }
                .accessibilityLabel("get started")
                .accessibilityHint("opens the app")

                Text("private by default · no account required")
                    .appFont(12, .light, relativeTo: .caption)
                    .foregroundStyle(AppColors.tertiaryText)
                    .accessibilityLabel("private by default, no account required")
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 56)
        }
    }
}
