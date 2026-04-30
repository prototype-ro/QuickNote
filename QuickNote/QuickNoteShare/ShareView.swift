// ShareView.swift — confirmation card shown inside the share sheet

import SwiftUI

struct ShareView: View {
    let urlString: String
    let title: String
    let host: String
    var onSave: () -> Void
    var onCancel: () -> Void

    var body: some View {
        ZStack(alignment: .bottom) {
            // Dim backdrop — tap to cancel
            Color.black.opacity(0.22)
                .ignoresSafeArea()
                .onTapGesture(perform: onCancel)

            VStack(alignment: .leading, spacing: 0) {
                // Drag handle
                HStack {
                    Capsule()
                        .fill(Color(hex: "0A0A0B").opacity(0.18))
                        .frame(width: 36, height: 5)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 10)
                .padding(.bottom, 22)

                // Title
                VStack(alignment: .leading, spacing: 4) {
                    Text("save to library")
                        .font(.system(size: 22, weight: .bold))
                        .tracking(-0.5)
                        .foregroundColor(Color(hex: "0A0A0B"))

                    Text(host)
                        .font(.system(size: 13, weight: .light))
                        .foregroundColor(Color(hex: "6B7280"))
                }
                .padding(.bottom, 18)

                // URL preview pill
                Text(urlString)
                    .font(.system(size: 11, weight: .light))
                    .foregroundColor(Color(hex: "9CA3AF"))
                    .lineLimit(2)
                    .truncationMode(.middle)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white.opacity(0.6))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.white.opacity(0.7), lineWidth: 0.5)
                    )
                    .padding(.bottom, 20)

                // Buttons
                HStack(spacing: 10) {
                    Button(action: onCancel) {
                        Text("cancel")
                            .font(.system(size: 15, weight: .regular))
                            .foregroundColor(Color(hex: "6B7280"))
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color(hex: "0A0A0B").opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 13))
                    }

                    Button(action: onSave) {
                        Text("save")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(
                                LinearGradient(
                                    colors: [Color(hex: "1a1a1d"), .black],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 13))
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
            .background(Color(hex: "F4F6F8"))
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        }
        .ignoresSafeArea()
    }
}

// MARK: - Color(hex:) — duplicated here since extensions are separate binaries

private extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB, red: Double(r)/255, green: Double(g)/255, blue: Double(b)/255, opacity: Double(a)/255)
    }
}
