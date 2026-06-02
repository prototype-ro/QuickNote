// DevelopEditorView.swift — a focused full-screen space for growing one thought
// into long-form (paragraphs, code). Deliberately entered; capture stays short.

import SwiftUI

struct DevelopEditorView: View {
    let note: Note
    var onClose: () -> Void

    @State private var draft: String = ""
    @State private var monospace: Bool = false
    @FocusState private var focused: Bool

    private var wordCount: Int {
        draft.split { $0 == " " || $0 == "\n" || $0 == "\t" }.count
    }

    var body: some View {
        ZStack {
            WallpaperView().ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                editor
            }
        }
        .onAppear {
            draft = note.displayText ?? note.rawText
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { focused = true }
        }
    }

    private var topBar: some View {
        HStack(spacing: 14) {
            Button { save(); onClose() } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(AppColors.secondaryText)
                    .frame(width: 36, height: 36)
                    .background(AppColors.ink.opacity(0.05))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            Spacer()

            Text("\(wordCount) word\(wordCount == 1 ? "" : "s")")
                .font(.system(size: 12, weight: .light))
                .monospacedDigit()
                .foregroundStyle(AppColors.tertiaryText)
                .contentTransition(.numericText())

            Button { monospace.toggle() } label: {
                Image(systemName: "chevron.left.forwardslash.chevron.right")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(monospace ? AppColors.onAccent : AppColors.secondaryText)
                    .frame(width: 36, height: 36)
                    .background(monospace
                                ? AnyShapeStyle(LinearGradient(colors: [AppColors.ctaTop, AppColors.ctaBottom],
                                                               startPoint: .top, endPoint: .bottom))
                                : AnyShapeStyle(AppColors.ink.opacity(0.05)))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .frame(height: 52)
    }

    private var editor: some View {
        TextEditor(text: $draft)
            .font(monospace
                  ? .system(size: 15, weight: .regular, design: .monospaced)
                  : .system(size: 17, weight: .light))
            .tracking(monospace ? 0 : -0.1)
            .lineSpacing(monospace ? 3 : 7)
            .foregroundStyle(AppColors.primaryText)
            .tint(AppColors.primaryText)
            .scrollContentBackground(.hidden)
            .focused($focused)
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("done") { save(); focused = false }
                }
            }
    }

    private func save() {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        note.displayText = trimmed
        EmbeddingService.shared.reembed(note)
    }
}
