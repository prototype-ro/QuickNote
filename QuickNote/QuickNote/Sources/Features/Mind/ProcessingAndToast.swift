// ProcessingAndToast.swift — ProcessingOverlay, LibraryToast, DigestCard, MindEmptyState

import SwiftUI

// MARK: - ProcessingOverlay

struct ProcessingOverlay: View {
    var capturedText: String = ""
    @State private var appeared = false
    @State private var textAppeared = false

    private var processingLabel: String {
        let lower = capturedText.lowercased()
        if capturedText.count >= 80 { return "reading this carefully…" }
        if lower.contains("?") { return "considering your question…" }
        if capturedText.count <= 20 { return "capturing this…" }
        let week = Calendar.current.component(.weekOfYear, from: Date())
        let labels = ["thinking…", "with you.", "not lost.", "noted."]
        return labels[week % labels.count]
    }

    var body: some View {
        ZStack {
            AppColors.background.opacity(0.55)
                .background(.ultraThinMaterial.opacity(0.4))
                .ignoresSafeArea()

            VStack(spacing: 32) {
                if !capturedText.isEmpty {
                    Text(capturedText)
                        .font(.system(size: 17, weight: .light))
                        .italic()
                        .tracking(-0.2)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(AppColors.primaryText.opacity(0.65))
                        .padding(.horizontal, 36)
                        .fixedSize(horizontal: false, vertical: true)
                        .opacity(textAppeared ? 1 : 0)
                        .offset(y: textAppeared ? 0 : 6)
                }

                VStack(spacing: 14) {
                    HeroMark(size: 52, haloColor: AppColors.accentBlue, breathe: true)

                    Text(processingLabel)
                        .font(.system(size: 13, weight: .light))
                        .italic()
                        .tracking(-0.1)
                        .foregroundStyle(AppColors.secondaryText)
                }
            }
        }
        .opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(.easeIn(duration: 0.2)) { appeared = true }
            withAnimation(.easeOut(duration: 0.35).delay(0.15)) { textAppeared = true }
        }
    }
}

// MARK: - LibraryToast

struct LibraryToast: View {
    var isVisible: Bool
    var onPeek: () -> Void

    var body: some View {
        HStack {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [AppColors.accentBlue.opacity(0.33), .clear],
                                center: .center, startRadius: 0, endRadius: 11
                            )
                        )
                        .frame(width: 22, height: 22)
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(AppColors.primaryText)
                }

                Text("saved to library")
                    .font(.system(size: 13, weight: .regular))
                    .tracking(-0.1)
                    .foregroundStyle(AppColors.primaryText)
            }

            Spacer()

            Button {
                onPeek()
            } label: {
                HStack(spacing: 4) {
                    Text("peek")
                        .font(.system(size: 12, weight: .medium))
                        .tracking(-0.05)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundStyle(AppColors.primaryText)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.6), lineWidth: 0.5)
        )
        .opacity(isVisible ? 1 : 0)
        .offset(y: isVisible ? 0 : 8)
        .animation(.spring(response: 0.24, dampingFraction: 0.8), value: isVisible)
    }
}

// MARK: - DigestCard

struct DigestCard: View {
    let allNotes: [Note]
    var linkCount: Int = 0
    var onTap: () -> Void = {}

    private static let weeklyQuotes = [
        "clarity compounds.",
        "the mind that captures, creates.",
        "every note is a decision made.",
        "small thoughts, big patterns."
    ]

    private var weeklyQuote: String {
        let week = Calendar.current.component(.weekOfYear, from: Date())
        return Self.weeklyQuotes[week % 4]
    }

    private var weekRange: String {
        let cal = Calendar.current
        let now = Date()
        var comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
        comps.weekday = 1
        let start = cal.date(from: comps) ?? now
        let end = cal.date(byAdding: .day, value: 6, to: start) ?? now
        return "\(Self.monthDayFormatter.string(from: start)) – \(Self.monthDayFormatter.string(from: end))"
    }

    private static let monthDayFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "MMM d"; return f
    }()

    private var stats: (thoughts: Int, tasks: Int, ideas: Int) {
        let cal = Calendar.current
        let now = Date()
        let weekStart = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) ?? now
        let thisWeek = allNotes.filter { $0.createdAt >= weekStart && !$0.isArchived }
        return (
            thoughts: thisWeek.count,
            tasks: thisWeek.filter { $0.type == .task }.count,
            ideas: thisWeek.filter { $0.type == .idea }.count
        )
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 14) {
                Text(weekRange)
                    .font(.system(size: 13, weight: .regular))
                    .tracking(-0.05)
                    .foregroundStyle(AppColors.secondaryText)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    statCell(value: stats.thoughts, label: "thoughts")
                    statCell(value: stats.tasks,    label: "tasks")
                    statCell(value: stats.ideas,    label: "ideas")
                    statCell(value: linkCount,       label: "links")
                }

                Text(weeklyQuote)
                    .font(.system(size: 13, weight: .light))
                    .italic()
                    .tracking(-0.05)
                    .foregroundStyle(AppColors.tertiaryText)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.6), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    private func statCell(value: Int, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(value)")
                .font(.system(size: 22, weight: .semibold))
                .tracking(-0.5)
                .foregroundStyle(AppColors.primaryText)
            Text(label)
                .font(.system(size: 11, weight: .light))
                .tracking(-0.05)
                .foregroundStyle(AppColors.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - DigestDetailSheet

struct DigestDetailSheet: View {
    let allNotes: [Note]
    var onClose: () -> Void
    var onOpenNote: (Note) -> Void = { _ in }

    @State private var sheetDragOffset: CGFloat = 0

    /// One older reflective note whose meaning is closest to this week's captures —
    /// surfaced so the past comes back when it's relevant. Semantic, on-device.
    private var resurfaced: Note? {
        let now = Date()
        let weekAgo = now.addingTimeInterval(-7 * 24 * 60 * 60)
        let twoWeeksAgo = now.addingTimeInterval(-14 * 24 * 60 * 60)
        let reflective: (Note) -> Bool = { !$0.isArchived && ($0.type == .note || $0.type == .idea) }

        let recentAll = allNotes.filter { reflective($0) && $0.createdAt >= weekAgo }
        // Work within a single language space — mixing them makes the centroid meaningless.
        let lang = Dictionary(grouping: recentAll, by: { $0.langCode })
            .max { $0.value.count < $1.value.count }?.key ?? ""
        let recent = recentAll.filter { $0.langCode == lang }
        let centroid = SemanticIndex.centroid(of: recent.map { $0.embedding })
        guard !centroid.isEmpty else { return nil }

        let older = allNotes.filter { reflective($0) && $0.createdAt < twoWeeksAgo && $0.langCode == lang }
        return SemanticIndex.bestMatch(to: centroid, among: older, threshold: 0.45)?.note
    }

    private var last7Days: [(dayName: String, date: Date, count: Int)] {
        let cal = Calendar.current
        let now = Date()
        return (0..<7).reversed().compactMap { offset -> (String, Date, Int)? in
            guard let date = cal.date(byAdding: .day, value: -offset, to: now) else { return nil }
            let start = cal.startOfDay(for: date)
            guard let end = cal.date(byAdding: .day, value: 1, to: start) else { return nil }
            let count = allNotes.filter { $0.createdAt >= start && $0.createdAt < end && !$0.isArchived }.count
            return (Self.weekdayFormatter.string(from: date), date, count)
        }
    }

    private static let weekdayFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "EEE"; return f
    }()

    var body: some View {
        ZStack(alignment: .bottom) {
            AppColors.ink.opacity(0.18)
                .ignoresSafeArea()
                .background(.ultraThinMaterial.opacity(0.3))
                .onTapGesture(perform: onClose)

            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Capsule()
                        .fill(AppColors.ink.opacity(0.18))
                        .frame(width: 36, height: 5)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 10)
                .padding(.bottom, 20)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            sheetDragOffset = max(0, value.translation.height)
                        }
                        .onEnded { value in
                            if value.translation.height > 80 || value.predictedEndTranslation.height > 180 {
                                onClose()
                            } else {
                                withAnimation(AppAnimation.springSnappy) { sheetDragOffset = 0 }
                            }
                        }
                )

                VStack(alignment: .leading, spacing: 6) {
                    Text("this week")
                        .font(.system(size: 13, weight: .light))
                        .italic()
                        .foregroundStyle(AppColors.tertiaryText)

                    Text("your week in review.")
                        .font(.system(size: 22, weight: .bold))
                        .tracking(-0.5)
                        .foregroundStyle(AppColors.primaryText)
                }
                .padding(.bottom, 24)

                VStack(spacing: 0) {
                    ForEach(last7Days, id: \.date) { item in
                        HStack {
                            Text(item.dayName)
                                .font(.system(size: 15, weight: .light))
                                .foregroundStyle(AppColors.primaryText)
                            Spacer()
                            Text("\(item.count)")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(AppColors.primaryText)
                        }
                        .padding(.vertical, 12)
                        if item.date != last7Days.last?.date {
                            Divider().opacity(0.12)
                        }
                    }
                }

                if let note = resurfaced {
                    resurfacedSection(note)
                }

                Spacer(minLength: 34)
            }
            .padding(.horizontal, 28)
            .background {
                ZStack {
                    Rectangle().fill(.ultraThinMaterial)
                    Color.white.opacity(0.45)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(Color.white.opacity(0.6), lineWidth: 0.5)
                    .padding(.bottom, -28)
            )
            .frame(maxHeight: ((UIApplication.shared.connectedScenes.first as? UIWindowScene)?.screen.bounds.height ?? 852) * 0.58)
            .offset(y: sheetDragOffset)
        }
        .ignoresSafeArea()
    }

    @ViewBuilder
    private func resurfacedSection(_ note: Note) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider().opacity(0.12).padding(.vertical, 4)

            Text("you wrote this. still true?")
                .font(.system(size: 12, weight: .light))
                .italic()
                .tracking(-0.05)
                .foregroundStyle(AppColors.tertiaryText)

            Button { onOpenNote(note) } label: {
                Text(note.embeddingSource)
                    .font(.system(size: 14, weight: .light))
                    .italic()
                    .tracking(-0.1)
                    .lineSpacing(4)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                    .foregroundStyle(AppColors.primaryText.opacity(0.75))
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 8)
    }
}

// MARK: - Empty State

struct MindEmptyState: View {
    var variant: EmptyVariant = .first

    enum EmptyVariant: Equatable {
        case first, inbox, filter(FilterType)

        static func == (lhs: Self, rhs: Self) -> Bool {
            switch (lhs, rhs) {
            case (.first, .first), (.inbox, .inbox): return true
            case (.filter(let a), .filter(let b)): return a == b
            default: return false
            }
        }

        var heroSize: CGFloat {
            switch self {
            case .inbox, .first: return 68
            case .filter: return 56
            }
        }

        var heading: String {
            switch self {
            case .first:  return "nothing here yet."
            case .inbox:  return "your brain's offsite."
            case .filter: return "nothing here."
            }
        }

        var subtext: String {
            switch self {
            case .first:         return "capture your first thought."
            case .inbox:         return "fill it back up."
            case .filter(let f): return f == .archived ? "nothing archived yet." : "no \(f.label) yet."
            }
        }

        var breathe: Bool {
            if case .first = self { return true }
            return false
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HeroMark(size: variant.heroSize, haloColor: AppColors.accentBlue, breathe: variant.breathe)
                .padding(.bottom, 14)

            Text(variant.heading)
                .font(.system(size: 19, weight: .bold))
                .tracking(-0.4)
                .foregroundStyle(AppColors.primaryText)

            Text(variant.subtext)
                .font(.system(size: 13, weight: .light))
                .tracking(-0.1)
                .multilineTextAlignment(.center)
                .foregroundStyle(AppColors.secondaryText)
                .frame(maxWidth: 240)
                .padding(.top, 6)
        }
    }
}
