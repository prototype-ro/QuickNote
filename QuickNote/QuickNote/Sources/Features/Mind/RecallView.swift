// RecallView.swift — the second-mind query space.
// Ask your corpus; your own fragments float up; Claude stitches one quiet line.

import SwiftUI

/// A calm overlay where the user queries their entire corpus by meaning.
/// Retrieval is on-device (top-k cosine); Claude sees only the matched snippets
/// and returns one connective sentence, rendered lighter than the user's words.
struct RecallView: View {
    let notes: [Note]
    let processor: NoteProcessor
    var onClose: () -> Void
    var onOpenNote: (Note) -> Void

    @State private var query: String = ""
    @State private var matches: [Note] = []
    @State private var stitch: String = ""
    @State private var phase: Phase = .idle
    @State private var dragOffset: CGFloat = 0
    @FocusState private var focused: Bool

    private enum Phase { case idle, thinking, answered, empty }

    /// Notes eligible for recall: the user's own thoughts, not links/digests/archived.
    private var corpus: [Note] {
        notes.filter { !$0.isArchived && ($0.type == .note || $0.type == .idea || $0.type == .task) }
    }

    var body: some View {
        ZStack(alignment: .top) {
            // Opaque surface — recall is its own space; the inbox must not bleed through.
            WallpaperView()
                .ignoresSafeArea()
            AppColors.background.opacity(0.82)
                .background(.ultraThinMaterial)
                .ignoresSafeArea()
                .onTapGesture { close() }

            VStack(alignment: .leading, spacing: 0) {
                handle
                header
                queryField
                content
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 24)
            .offset(y: dragOffset)
        }
        .onAppear { focused = true }
    }

    private var handle: some View {
        VStack(spacing: 6) {
            Capsule()
                .fill(AppColors.ink.opacity(0.22))
                .frame(width: 40, height: 5)
            Image(systemName: "chevron.compact.down")
                .appFont(18, .regular, relativeTo: .title3)
                .foregroundStyle(AppColors.tertiaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 12)
        .padding(.bottom, 20)
        .contentShape(Rectangle())
        .onTapGesture { close() }
        .gesture(
            DragGesture()
                .onChanged { dragOffset = max(0, $0.translation.height) }
                .onEnded {
                    if $0.translation.height > 80 { close() }
                    else { withAnimation(AppAnimation.springSnappy) { dragOffset = 0 } }
                }
        )
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("recall")
                .appFont(13, .light, relativeTo: .subheadline)
                .italic()
                .foregroundStyle(AppColors.tertiaryText)
            Text("ask your mind.")
                .appFont(24, .bold, relativeTo: .title2)
                .tracking(-0.5)
                .foregroundStyle(AppColors.primaryText)
        }
        .padding(.bottom, 18)
    }

    private var queryField: some View {
        HStack(spacing: 10) {
            TextField("what did you conclude about…", text: $query, axis: .vertical)
                .appFont(16, .light, relativeTo: .body)
                .tracking(-0.15)
                .lineLimit(1...3)
                .foregroundStyle(AppColors.primaryText)
                .tint(AppColors.primaryText)
                .focused($focused)
                .onSubmit(run)

            if !query.isEmpty {
                Button(action: run) {
                    ZStack {
                        LinearGradient(colors: [AppColors.ctaTop, AppColors.ctaBottom],
                                       startPoint: .top, endPoint: .bottom)
                        Image(systemName: "arrow.up")
                            .appFont(13, .semibold, relativeTo: .subheadline)
                            .foregroundStyle(AppColors.onAccent)
                    }
                    .frame(width: 32, height: 32)
                    .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.6), lineWidth: 0.5))
        .padding(.bottom, 20)
    }

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .idle:
            Text("retrieved from your own words. nothing leaves but the matches.")
                .appFont(12, .light, relativeTo: .caption)
                .italic()
                .foregroundStyle(AppColors.tertiaryText)
        case .thinking:
            HStack(spacing: 10) {
                HeroMark(size: 22, haloColor: AppColors.accentBlue, breathe: true)
                Text("gathering…")
                    .appFont(13, .light, relativeTo: .subheadline)
                    .italic()
                    .foregroundStyle(AppColors.secondaryText)
            }
        case .empty:
            Text("nothing in here speaks to that — yet.")
                .appFont(13, .light, relativeTo: .subheadline)
                .italic()
                .foregroundStyle(AppColors.secondaryText)
        case .answered:
            answer
        }
    }

    private var answer: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if !stitch.isEmpty {
                    Text(stitch)
                        .appFont(15, .light, relativeTo: .body)
                        .tracking(-0.1)
                        .lineSpacing(5)
                        .foregroundStyle(AppColors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                ForEach(matches, id: \.id) { note in
                    fragmentCard(note)
                }
            }
            .padding(.bottom, 40)
        }
    }

    private func fragmentCard(_ note: Note) -> some View {
        Button { onOpenNote(note) } label: {
            VStack(alignment: .leading, spacing: 6) {
                Text(note.embeddingSource)
                    .appFont(14, .light, relativeTo: .subheadline)
                    .tracking(-0.1)
                    .lineSpacing(4)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                    .foregroundStyle(AppColors.primaryText.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
                Text(relativeTime(note.createdAt))
                    .appFont(11, .light, relativeTo: .caption2)
                    .foregroundStyle(AppColors.tertiaryText)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial.opacity(0.7))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.4), lineWidth: 0.5))
        }
        .buttonStyle(.plain)
    }

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f
    }()

    private func relativeTime(_ date: Date) -> String {
        Self.relativeFormatter.localizedString(for: date, relativeTo: Date())
    }

    // MARK: - Actions

    private func run() {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return }
        focused = false
        let embedded = EmbeddingService.shared.embed(q)
        // Compare only within the query's language space.
        let sameLang = corpus.filter { $0.langCode == embedded.language }
        let top = SemanticIndex.topK(5, to: embedded.vector, among: sameLang).map { $0.note }
        guard !top.isEmpty else {
            withAnimation(AppAnimation.springFluid) { phase = .empty }
            return
        }
        withAnimation(AppAnimation.springFluid) {
            matches = top
            stitch = ""
            phase = .thinking
        }
        let snippets = top.map { $0.embeddingSource }
        Task {
            let line = (try? await processor.synthesize(query: q, snippets: snippets)) ?? ""
            await MainActor.run {
                withAnimation(AppAnimation.springFluid) {
                    stitch = line
                    phase = .answered
                }
            }
        }
    }

    private func close() {
        focused = false
        onClose()
    }
}
