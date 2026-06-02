// GlossButton.swift — black gradient CTA, used on splash only

import SwiftUI

struct GlossButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(title, action: action)
            .buttonStyle(GlossButtonStyle())
    }
}

private struct GlossButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        ZStack(alignment: .top) {
            LinearGradient(
                stops: [
                    .init(color: Color(hex: "1a1a1d"), location: 0),
                    .init(color: AppColors.ink, location: 0.6),
                    .init(color: .black,               location: 1),
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            // Top sheen
            LinearGradient(
                colors: [Color.white.opacity(0.10), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 26)

            configuration.label
                .font(.system(size: 16, weight: .medium))
                .tracking(-0.1)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(height: 52)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(configuration.isPressed ? 0.04 : 0.18), lineWidth: 1)
        )
        .shadow(
            color: .black.opacity(configuration.isPressed ? 0.10 : 0.18),
            radius: configuration.isPressed ? 2 : 5,
            x: 0,
            y: configuration.isPressed ? 1 : 4
        )
        .scaleEffect(configuration.isPressed ? 0.99 : 1.0)
        .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
