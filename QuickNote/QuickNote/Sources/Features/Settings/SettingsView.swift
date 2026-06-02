// SettingsView.swift — appearance, export, and app info. Bottom-sheet overlay.

import SwiftUI

struct SettingsView: View {
    let notes: [Note]
    var onClose: () -> Void

    @Environment(AppState.self) private var appState
    @State private var dragOffset: CGFloat = 0

    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            AppColors.scrim.opacity(0.18)
                .ignoresSafeArea()
                .background(.ultraThinMaterial.opacity(0.3))
                .onTapGesture(perform: onClose)

            sheet
                .offset(y: dragOffset)
                .animation(AppAnimation.springFluid, value: dragOffset)
        }
        .ignoresSafeArea()
    }

    private var sheet: some View {
        VStack(alignment: .leading, spacing: 0) {
            handle

            Text("settings")
                .appFont(22, .bold, relativeTo: .title2)
                .tracking(-0.5)
                .foregroundStyle(AppColors.primaryText)
                .padding(.bottom, 24)

            sectionLabel("APPEARANCE")
            appearancePicker.padding(.bottom, 26)

            sectionLabel("YOUR NOTES")
            ShareLink(item: ExportService.document(from: notes),
                      preview: SharePreview("QuickNote export")) {
                rowLabel(icon: "square.and.arrow.up", text: "export all notes",
                         detail: "\(notes.filter { !$0.isArchived }.count) thoughts")
            }
            .buttonStyle(.plain)
            .padding(.bottom, 26)

            sectionLabel("ABOUT")
            rowLabel(icon: "info.circle", text: "version", detail: appVersion)

            Spacer(minLength: 28)
        }
        .padding(.horizontal, 28)
        .background {
            ZStack {
                Rectangle().fill(.ultraThinMaterial)
                AppColors.surface.opacity(0.45)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.6), lineWidth: 0.5)
                .padding(.bottom, -28)
        )
        .frame(maxHeight: ((UIApplication.shared.connectedScenes.first as? UIWindowScene)?.screen.bounds.height ?? 852) * 0.6)
    }

    private var handle: some View {
        VStack(spacing: 6) {
            Capsule()
                .fill(AppColors.ink.opacity(0.18))
                .frame(width: 40, height: 5)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 12)
        .padding(.bottom, 20)
        .contentShape(Rectangle())
        .gesture(
            DragGesture()
                .onChanged { dragOffset = max(0, $0.translation.height) }
                .onEnded {
                    if $0.translation.height > 80 { onClose() }
                    else { withAnimation(AppAnimation.springSnappy) { dragOffset = 0 } }
                }
        )
    }

    private var appearancePicker: some View {
        HStack(spacing: 8) {
            ForEach(AppearanceMode.allCases, id: \.self) { mode in
                let active = appState.appearance == mode
                Button {
                    withAnimation(AppAnimation.springSnappy) { appState.appearance = mode }
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: mode.icon)
                            .appFont(16, .light, relativeTo: .body)
                        Text(mode.label)
                            .appFont(12, .medium, relativeTo: .caption)
                            .tracking(-0.05)
                    }
                    .foregroundStyle(active ? AppColors.onAccent : AppColors.secondaryText)
                    .frame(maxWidth: .infinity)
                    .frame(height: 64)
                    .background(active
                                ? AnyShapeStyle(LinearGradient(colors: [AppColors.ctaTop, AppColors.ctaBottom],
                                                               startPoint: .top, endPoint: .bottom))
                                : AnyShapeStyle(AppColors.ink.opacity(0.04)))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14)
                        .stroke(AppColors.ink.opacity(active ? 0 : 0.06), lineWidth: 0.5))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .appFont(10.5, .medium, relativeTo: .caption2)
            .tracking(1.4)
            .foregroundStyle(AppColors.tertiaryText)
            .padding(.bottom, 12)
    }

    private func rowLabel(icon: String, text: String, detail: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .appFont(15, .light, relativeTo: .body)
                .foregroundStyle(AppColors.secondaryText)
                .frame(width: 22)
            Text(text)
                .appFont(15, .light, relativeTo: .body)
                .foregroundStyle(AppColors.primaryText)
            Spacer()
            Text(detail)
                .appFont(13, .light, relativeTo: .subheadline)
                .foregroundStyle(AppColors.tertiaryText)
        }
        .frame(minHeight: 36)
    }
}
