// EchoThread.swift — the "memory surfacing" beneath a freshly captured note.
// A hairline thread down to one line of the user's own past note, verbatim.

import SwiftUI

/// A quiet, decaying surface that hands the user back their own past words when
/// a new capture semantically echoes something they wrote before.
///
/// Speaks in the user's voice (verbatim, no AI synthesis), never demands a tap,
/// and fades on its own. Tapping it opens the past note.
struct EchoThread: View {
    let note: Note
    var onTap: () -> Void = {}

    @State private var appeared = false

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f
    }()

    private var relativeTime: String {
        Self.relativeFormatter.localizedString(for: note.createdAt, relativeTo: Date())
    }

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 10) {
                // Hairline connector descending from the new card.
                VStack(spacing: 0) {
                    Rectangle()
                        .fill(AppColors.tertiaryText.opacity(0.35))
                        .frame(width: 0.5, height: 14)
                    Circle()
                        .fill(AppColors.accentBlue.opacity(0.5))
                        .frame(width: 4, height: 4)
                }
                .padding(.leading, 18)

                VStack(alignment: .leading, spacing: 3) {
                    Text("you wrote, \(relativeTime)")
                        .font(.system(size: 10.5, weight: .light))
                        .tracking(0.1)
                        .foregroundStyle(AppColors.tertiaryText.opacity(0.8))

                    Text(note.embeddingSource)
                        .font(.system(size: 13, weight: .light))
                        .italic()
                        .tracking(-0.1)
                        .lineSpacing(3)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .foregroundStyle(AppColors.primaryText.opacity(0.5))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(.trailing, 16)
            .padding(.top, 2)
            .padding(.bottom, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : -4)
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) { appeared = true }
        }
    }
}
