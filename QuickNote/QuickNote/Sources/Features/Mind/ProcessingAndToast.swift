// ProcessingAndToast.swift — ProcessingOverlay, LibraryToast, DigestCard, MindEmptyState

import SwiftUI

// MARK: - ProcessingOverlay

struct ProcessingOverlay: View {
    @State private var appeared = false

    var body: some View {
        ZStack {
            Color(hex: "F0F2F4").opacity(0.55)
                .background(.ultraThinMaterial.opacity(0.4))
                .ignoresSafeArea()

            VStack(spacing: 18) {
                HeroMark(size: 64, haloColor: AppColors.accentBlue, breathe: true)

                Text("thinking…")
                    .font(.system(size: 15, weight: .light))
                    .italic()
                    .tracking(-0.1)
                    .foregroundStyle(AppColors.secondaryText)
            }
        }
        .opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(.easeIn(duration: 0.2)) { appeared = true }
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
    var onTap: () -> Void = {}

    private var weekRange: String {
        let cal = Calendar.current
        let now = Date()
        var comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
        comps.weekday = 1
        let start = cal.date(from: comps) ?? now
        let end = cal.date(byAdding: .day, value: 6, to: start) ?? now
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM d"
        return "\(fmt.string(from: start)) – \(fmt.string(from: end))"
    }

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
                    .font(.system(size: 12, weight: .light))
                    .tracking(-0.05)
                    .foregroundStyle(AppColors.tertiaryText)

                VStack(alignment: .leading, spacing: 6) {
                    statRow(value: stats.thoughts, label: "thoughts captured")
                    statRow(value: stats.tasks,    label: "tasks noted")
                    statRow(value: stats.ideas,    label: "ideas saved")
                }
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

    private func statRow(value: Int, label: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text("\(value)")
                .font(.system(size: 17, weight: .semibold))
                .tracking(-0.3)
                .foregroundStyle(AppColors.primaryText)
            Text(label)
                .font(.system(size: 13, weight: .light))
                .tracking(-0.1)
                .foregroundStyle(AppColors.secondaryText)
        }
    }
}

// MARK: - DigestDetailSheet

struct DigestDetailSheet: View {
    let allNotes: [Note]
    var onClose: () -> Void

    private var weekStart: Date {
        let cal = Calendar.current
        let now = Date()
        return cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) ?? now
    }

    private var thisWeekNotes: [Note] {
        allNotes.filter { $0.createdAt >= weekStart && !$0.isArchived }
    }

    private var breakdown: [(type: NoteType, count: Int)] {
        NoteType.allCases
            .filter { $0 != .digest }
            .map { type in (type: type, count: thisWeekNotes.filter { $0.type == type }.count) }
            .filter { $0.count > 0 }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color(hex: "0A0A0B").opacity(0.18)
                .ignoresSafeArea()
                .background(.ultraThinMaterial.opacity(0.3))
                .onTapGesture(perform: onClose)

            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Capsule()
                        .fill(Color(hex: "0A0A0B").opacity(0.18))
                        .frame(width: 36, height: 5)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 10)
                .padding(.bottom, 20)

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
                    ForEach(breakdown, id: \.type) { item in
                        HStack(spacing: 12) {
                            CatIcon(kind: item.type, size: 13, color: AppColors.tertiaryText)
                            Text(item.type.rawValue.capitalized)
                                .font(.system(size: 15, weight: .light))
                                .foregroundStyle(AppColors.primaryText)
                            Spacer()
                            Text("\(item.count)")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(AppColors.primaryText)
                        }
                        .padding(.vertical, 12)
                        if item.type != breakdown.last?.type {
                            Divider().opacity(0.12)
                        }
                    }
                }

                Spacer(minLength: 34)
            }
            .padding(.horizontal, 28)
            .background(Color(hex: "F4F6F8"))
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(Color.white.opacity(0.6), lineWidth: 0.5)
                    .padding(.bottom, -28)
            )
            .frame(maxHeight: UIScreen.main.bounds.height * 0.5)
        }
        .ignoresSafeArea()
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
