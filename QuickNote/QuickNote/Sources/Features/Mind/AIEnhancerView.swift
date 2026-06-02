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
            modeChips

            if isEnhancing {
                enhancingIndicator
            } else if let enhanced = enhancedText {
                resultView(enhanced)
            } else if let err = errorMessage {
                Text(err)
                    .font(.system(size: 12.5, weight: .light))
                    .foregroundStyle(AppColors.tertiaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .transition(.opacity)
            }
        }
        .sheet(isPresented: $showProPrompt) {
            ProUpgradeSheet()
        }
    }

    private var modeChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(EnhancementMode.allCases, id: \.self) { mode in
                    modeChip(mode)
                }
            }
        }
    }

    private func modeChip(_ mode: EnhancementMode) -> some View {
        let isActive = selectedMode == mode
        return Button {
            guard !isEnhancing else { return }
            if !isPro {
                showProPrompt = true
                return
            }
            runEnhancement(mode)
        } label: {
            Text(mode.label)
                .font(.system(size: 10.5, weight: .medium))
                .tracking(0.3)
                .textCase(.uppercase)
                .foregroundStyle(isActive ? AppColors.onAccent : AppColors.secondaryText)
                .padding(.horizontal, 10)
                .frame(height: 26)
                .background(
                    isActive
                        ? AnyShapeStyle(LinearGradient(colors: [AppColors.ctaTop, AppColors.ctaBottom],
                                                       startPoint: .top, endPoint: .bottom))
                        : AnyShapeStyle(AppColors.ink.opacity(0.06))
                )
                .clipShape(Capsule())
                .overlay(Capsule().stroke(AppColors.ink.opacity(isActive ? 0 : 0.04), lineWidth: 0.5))
        }
        .buttonStyle(.plain)
    }

    private var enhancingIndicator: some View {
        Text("enhancing…")
            .font(.system(size: 13, weight: .light))
            .italic()
            .foregroundStyle(AppColors.tertiaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func resultView(_ enhanced: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(enhanced)
                .font(.system(size: 15, weight: .light))
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
                        .font(.system(size: 13, weight: .medium))
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
                        .font(.system(size: 13, weight: .light))
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
                        .font(.system(size: 22, weight: .bold))
                        .tracking(-0.5)
                        .foregroundStyle(AppColors.primaryText)

                    Text("AI enhancement, unlimited captures, priority processing")
                        .font(.system(size: 13, weight: .light))
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
                        .font(.system(size: 13, weight: .light))
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
