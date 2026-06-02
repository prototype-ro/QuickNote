// AIEnhancerView.swift — AI enhancement mode selector and pro upgrade prompt

import SwiftUI

// MARK: - AI Enhancer inline view (embedded in NoteDetailSheet)

struct AIEnhancerInline: View {
    let note: Note
    let isPro: Bool
    var onKeep: (String, EnhancementMode) -> Void
    var onDismiss: () -> Void
    var onEnhancingChanged: (Bool) -> Void = { _ in }

    @State private var selectedMode: EnhancementMode? = nil
    @State private var enhancedText: String? = nil
    @State private var isEnhancing = false
    @State private var errorMessage: String? = nil
    @State private var showProPrompt = false
    @State private var textOpacity: Double = 1
    @State private var processor = NoteProcessor()

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if enhancedText == nil { enhanceButton }

            if isEnhancing {
                enhancingIndicator
            } else if let enhanced = enhancedText {
                resultView(enhanced)
            } else if let err = errorMessage {
                Text(err)
                    .appFont(12.5, .light, relativeTo: .caption)
                    .foregroundStyle(AppColors.tertiaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .transition(.opacity)
            }
        }
        .sheet(isPresented: $showProPrompt) {
            ProUpgradeSheet()
        }
    }

    private var enhanceButton: some View {
        Button {
            guard !isEnhancing else { return }
            if !isPro {
                showProPrompt = true
                return
            }
            runEnhancement(.enhance)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .appFont(11, .medium, relativeTo: .caption2)
                Text("enhance")
                    .appFont(11, .medium, relativeTo: .caption2)
                    .tracking(0.3)
                    .textCase(.uppercase)
            }
            .foregroundStyle(AppColors.secondaryText)
            .padding(.horizontal, 12)
            .frame(height: 28)
            .background(AppColors.ink.opacity(0.06))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(AppColors.ink.opacity(0.04), lineWidth: 0.5))
        }
        .buttonStyle(.plain)
    }

    private var enhancingIndicator: some View {
        Text("enhancing…")
            .appFont(13, .light, relativeTo: .subheadline)
            .italic()
            .foregroundStyle(AppColors.tertiaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func resultView(_ enhanced: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(enhanced)
                .appFont(15, .light, relativeTo: .body)
                .tracking(-0.15)
                .lineSpacing(4)
                .foregroundStyle(AppColors.primaryText)
                .opacity(textOpacity)

            HStack(spacing: 10) {
                Button {
                    if let mode = selectedMode {
                        onKeep(enhanced, mode)
                    }
                    onDismiss()
                } label: {
                    Text("keep")
                        .appFont(13, .medium, relativeTo: .subheadline)
                        .foregroundStyle(AppColors.onAccent)
                        .padding(.horizontal, 14)
                        .frame(height: 32)
                        .background(AppColors.ink)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                Button {
                    withAnimation(AppAnimation.springFluid) {
                        enhancedText = nil
                        selectedMode = nil
                    }
                    onDismiss()
                } label: {
                    Text("revert")
                        .appFont(13, .light, relativeTo: .subheadline)
                        .foregroundStyle(AppColors.secondaryText)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func runEnhancement(_ mode: EnhancementMode) {
        selectedMode = mode
        isEnhancing = true
        enhancedText = nil
        errorMessage = nil
        onEnhancingChanged(true)

        Task {
            do {
                let result = try await processor.enhanceNote(rawText: note.displayText ?? note.rawText, mode: mode)
                await MainActor.run {
                    withAnimation(AppAnimation.springFluid) {
                        isEnhancing = false
                        textOpacity = 0
                    }
                    withAnimation(AppAnimation.springFluid.delay(0.15)) {
                        enhancedText = result
                        textOpacity = 1
                    }
                    onEnhancingChanged(false)
                }
            } catch {
                await MainActor.run {
                    isEnhancing = false
                    selectedMode = nil
                    onEnhancingChanged(false)
                    withAnimation { errorMessage = "enhancement failed, try again" }
                    Task {
                        try? await Task.sleep(nanoseconds: 3_000_000_000)
                        await MainActor.run {
                            withAnimation { errorMessage = nil }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Pro upgrade sheet

struct ProUpgradeSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 20) {
                Text("✦")
                    .font(.system(size: 32))
                    .foregroundStyle(AppColors.primaryText)

                VStack(spacing: 6) {
                    Text("Quicknote Pro")
                        .appFont(22, .bold, relativeTo: .title2)
                        .tracking(-0.5)
                        .foregroundStyle(AppColors.primaryText)

                    Text("AI enhancement, unlimited captures, priority processing")
                        .appFont(13, .light, relativeTo: .subheadline)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(AppColors.secondaryText)
                        .frame(maxWidth: 240)
                }

                VStack(spacing: 10) {
                    GlossButton(title: "try for free") {
                        appState.isPro = true
                        dismiss()
                    }

                    Button("maybe later") { dismiss() }
                        .appFont(13, .light, relativeTo: .subheadline)
                        .foregroundStyle(AppColors.tertiaryText)
                        .buttonStyle(.plain)
                }
                .padding(.top, 4)
            }
            .padding(32)

            Spacer()
        }
        .presentationDetents([.height(280)])
        .presentationBackground(.ultraThinMaterial)
    }
}
