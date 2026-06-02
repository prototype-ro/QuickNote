// ShareView.swift — confirmation card shown inside the share sheet

import SwiftUI

struct ShareView: View {
    let urlString: String
    let title: String
    let host: String
    var onSave: (String) -> Void
    var onCancel: () -> Void

    @State private var contextNote = ""

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
                        .fill(Color(hex: "9CA3AF").opacity(0.6))
                        .frame(width: 36, height: 4)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 10)
                .padding(.bottom, 22)

                // Title
                VStack(alignment: .leading, spacing: 4) {
                    Text("save to library")
                        .font(.system(size: 22, weight: .bold))
                        .tracking(-0.5)
                        .foregroundStyle(Color(hex: "0A0A0B"))

                    Text(host)
                        .font(.system(size: 13, weight: .light))
                        .foregroundStyle(Color(hex: "6B7280"))
                }
                .padding(.bottom, 18)

                // URL preview
                Text(urlString)
                    .font(.system(size: 11, weight: .light))
                    .foregroundStyle(Color(hex: "9CA3AF"))
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
                    .padding(.bottom, 12)

                // Optional context note
                ZStack(alignment: .topLeading) {
                    if contextNote.isEmpty {
                        Text("add a note… (optional)")
                            .font(.system(size: 13, weight: .light))
                            .foregroundStyle(Color(hex: "9CA3AF"))
                            .padding(.top, 8)
                            .padding(.leading, 4)
                            .allowsHitTesting(false)
                    }
                    TextEditor(text: $contextNote)
                        .font(.system(size: 13, weight: .light))
                        .foregroundStyle(Color(hex: "0A0A0B"))
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 60)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.55))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.5), lineWidth: 0.5)
                )
                .padding(.bottom, 20)

                // Buttons
                HStack(spacing: 10) {
                    Button(action: onCancel) {
                        Text("cancel")
                            .font(.system(size: 15, weight: .regular))
                            .foregroundStyle(Color(hex: "6B7280"))
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color(hex: "0A0A0B").opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 13))
                    }

                    Button(action: { onSave(contextNote) }) {
                        Text("save")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
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
            .background {
                ZStack {
                    Rectangle().fill(.ultraThinMaterial)
                    Color.white.opacity(0.45)
                }
            }
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
