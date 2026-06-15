// NoteComponents.swift — NoteCard, Badge, CatIcon, FilterChips, CaptureBarView

import SwiftUI
import UIKit

// MARK: - Haptics

enum HapticEngine {
    static func submit() {
        let g = UIImpactFeedbackGenerator(style: .medium)
        g.prepare()
        g.impactOccurred()
    }

    static func noteArrived() {
        let g = UIImpactFeedbackGenerator(style: .light)
        g.prepare()
        g.impactOccurred()
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 90_000_000)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }

    static func classify() {
        UISelectionFeedbackGenerator().selectionChanged()
    }

    /// A single soft, low-intensity tap — the whisper of a memory surfacing.
    /// Gentler than `noteArrived`'s double-tap; used when an echo appears.
    static func echo() {
        let g = UIImpactFeedbackGenerator(style: .soft)
        g.prepare()
        g.impactOccurred(intensity: 0.45)
    }

    static func archive() {
        let g = UIImpactFeedbackGenerator(style: .soft)
        g.prepare()
        g.impactOccurred(intensity: 0.7)
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 120_000_000)
            UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.4)
        }
    }

    static func typeChange() {
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: 0.6)
    }
}

// MARK: - InkReveal

struct InkReveal: ViewModifier {
    var active: Bool
    @State private var progress: CGFloat = 0
    @State private var opacity: CGFloat = 1
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        if reduceMotion {
            // Fade in instead of pen-stroke sweep when motion is reduced.
            content
                .opacity(opacity)
                .onAppear {
                    if active { withAnimation(.easeOut(duration: 0.3)) { opacity = 1 } }
                }
        } else {
            content
                .mask(
                    GeometryReader { geo in
                        HStack(spacing: 0) {
                            Color.black
                                .frame(width: geo.size.width * progress)
                            LinearGradient(
                                colors: [.black, .clear],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                            .frame(width: min(geo.size.width * 0.10, 20))
                            Color.clear
                        }
                    }
                )
                .onAppear {
                    if active {
                        withAnimation(.easeOut(duration: 0.44)) { progress = 1 }
                    } else {
                        progress = 1
                    }
                }
        }
    }
}

extension View {
    func inkReveal(active: Bool = true) -> some View {
        modifier(InkReveal(active: active))
    }
}

// MARK: - CatIcon

struct CatIcon: View {
    let kind: NoteType
    var size: CGFloat = 11
    var color: Color = AppColors.primaryText

    var body: some View {
        Image(systemName: symbolName)
            .font(.system(size: size, weight: .light))
            .foregroundStyle(color)
    }

    private var symbolName: String {
        switch kind {
        case .task:   return "checkmark.circle"
        case .idea:   return "lightbulb"
        case .note:   return "doc"
        case .link:   return "link"
        case .digest: return "calendar"
        case .voice:  return "waveform"
        }
    }
}

// MARK: - Badge

struct NoteBadge: View {
    let kind: NoteType
    var animate: Bool = false

    @State private var appeared = false

    var body: some View {
        HStack(spacing: 5) {
            CatIcon(kind: kind, size: 11)
            Text(kind.rawValue)
                .appFont(10.5, .medium, relativeTo: .caption2)
                .tracking(0.8)
                .textCase(.uppercase)
        }
        .foregroundStyle(AppColors.primaryText)
        .padding(.horizontal, 9)
        .frame(minHeight: 22)
        .background(AppColors.ink.opacity(0.04))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(AppColors.ink.opacity(0.07), lineWidth: 0.5))
        .accessibilityLabel("\(kind.rawValue) type")
        .scaleEffect(appeared ? 1.0 : (animate ? 0.65 : 1.0))
        .opacity(appeared ? 1.0 : (animate ? 0.0 : 1.0))
        .onAppear {
            guard animate else { appeared = true; return }
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 320_000_000)
                withAnimation(.spring(response: 0.28, dampingFraction: 0.58)) {
                    appeared = true
                }
                HapticEngine.classify()
            }
        }
    }
}

// MARK: - NoteCard

struct NoteCard: View {
    let note: Note
    var repeatCount: Int = 0
    var isNew: Bool = false
    var onTap: () -> Void = {}
    var onArchive: () -> Void = {}
    var onDelete: () -> Void = {}

    @State private var dragOffset: CGFloat = 0
    @State private var showDeleteAlert = false
    @State private var isDragging = false
    @State private var dragAnchorOffset: CGFloat = 0
    @State private var swipeJustOpened = false
    @State private var showTypeFlash: Bool = false
    @State private var flashedType: NoteType = .note

    private let actionWidth: CGFloat = 76
    private let revealThreshold: CGFloat = 55

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f
    }()

    private var relativeTime: String {
        Self.relativeFormatter.localizedString(for: note.createdAt, relativeTo: Date())
    }

    private static let dueFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "MMM d"; return f
    }()

    private var subtitle: String {
        if note.type == .task && !note.tasks.isEmpty {
            let c = note.tasks.count
            let done = note.completedTaskCount
            var s = done > 0 ? "\(done)/\(c) done" : "\(c) action item\(c == 1 ? "" : "s") extracted"
            if let due = note.dueDate {
                s += " · due \(Self.dueFormatter.string(from: due))"
            }
            return s
        } else if !note.tags.isEmpty {
            return "tagged · \(note.tags.prefix(3).joined(separator: ", "))"
        }
        return ""
    }

    private var typeWarmthColor: Color { CategoryTint.wash(note.type) }

    var body: some View {
        ZStack {
            if dragOffset > 4 {
                HStack {
                    Button {
                        withAnimation(AppAnimation.springFluid) { dragOffset = 0 }
                        HapticEngine.archive()
                        onArchive()
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: "archivebox")
                                .appFont(15, .light, relativeTo: .body)
                            Text("ARCHIVE")
                                .appFont(10, .medium, relativeTo: .caption2)
                                .tracking(0.3)
                        }
                        .foregroundStyle(AppColors.secondaryText)
                        .frame(width: actionWidth)
                        .frame(maxHeight: .infinity)
                        .background(AppColors.ink.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }
            }

            if dragOffset < -4 {
                HStack {
                    Spacer()
                    Button { showDeleteAlert = true } label: {
                        VStack(spacing: 4) {
                            Image(systemName: "trash")
                                .appFont(15, .light, relativeTo: .body)
                            Text("DELETE")
                                .appFont(10, .medium, relativeTo: .caption2)
                                .tracking(0.3)
                        }
                        .foregroundStyle(.white)
                        .frame(width: actionWidth)
                        .frame(maxHeight: .infinity)
                        .background(AppColors.destructive)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .buttonStyle(.plain)
                }
            }

            Button {
                if swipeJustOpened {
                    swipeJustOpened = false
                } else if dragOffset != 0 {
                    withAnimation(AppAnimation.springSnappy) { dragOffset = 0 }
                } else {
                    onTap()
                }
            } label: {
                cardFace
            }
            .buttonStyle(PressStyle(scale: 0.985))
            .offset(x: dragOffset)
            .simultaneousGesture(cardDragGesture)

            // Type change flash badge
            if showTypeFlash {
                VStack {
                    HStack {
                        Spacer()
                        NoteBadge(kind: flashedType)
                            .transition(.scale(scale: 0.7).combined(with: .opacity))
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .allowsHitTesting(false)
            }
        }
        .alert("Delete this note?", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) {
                withAnimation(AppAnimation.springFluid) { dragOffset = 0 }
                onDelete()
            }
            Button("Cancel", role: .cancel) {
                withAnimation(AppAnimation.springSnappy) { dragOffset = 0 }
            }
        } message: {
            Text("This cannot be undone.")
        }
    }

    private var cardFace: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                NoteBadge(kind: note.type, animate: isNew)
                Spacer()
                HStack(spacing: 6) {
                    if note.hasMedia {
                        Text("✦")
                            .appFont(11, .medium, relativeTo: .caption)
                            .foregroundStyle(AppColors.secondaryText)
                            .accessibilityLabel("enriched")
                    }
                    Text(relativeTime)
                        .appFont(12, .light, relativeTo: .caption)
                        .tracking(-0.1)
                        .foregroundStyle(AppColors.secondaryText)
                    if repeatCount >= 3 {
                        Circle()
                            .fill(AppColors.secondaryText)
                            .frame(width: 6, height: 6)
                            .contextMenu {
                                Text("you've noted this \(repeatCount) times")
                            }
                    }
                }
            }

            Text(note.displayText ?? note.rawText)
                .appFont(15, .light, relativeTo: .body)
                .tracking(-0.15)
                .lineSpacing(6)
                .foregroundStyle(AppColors.primaryText)
                .lineLimit(note.isLongForm ? 6 : nil)
                .fixedSize(horizontal: false, vertical: note.isLongForm ? false : true)

            if note.isLongForm {
                HStack(spacing: 4) {
                    Image(systemName: "text.alignleft")
                        .appFont(9, .regular, relativeTo: .caption2)
                    Text("developed · tap to read")
                        .appFont(11, .light, relativeTo: .caption2)
                        .tracking(-0.05)
                }
                .foregroundStyle(AppColors.tertiaryText)
            }

            if !subtitle.isEmpty {
                Text(subtitle)
                    .appFont(12.5, .light, relativeTo: .caption)
                    .tracking(-0.1)
                    .foregroundStyle(AppColors.secondaryText)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            ZStack {
                Rectangle().fill(.ultraThinMaterial)
                typeWarmthColor
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.28), lineWidth: 3.5)
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color.white.opacity(0.75), Color.white.opacity(0.0)],
                            startPoint: .top,
                            endPoint: UnitPoint(x: 0.5, y: 0.55)
                        ),
                        lineWidth: 1.5
                    )
            }
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(note.type.rawValue). \(note.displayText ?? note.rawText)")
        .accessibilityHint("double tap to open")
    }

    // Single gesture handles both horizontal swipe (archive/delete) and vertical flick (type cycle)
    private var cardDragGesture: some Gesture {
        DragGesture(minimumDistance: 20, coordinateSpace: .local)
            .onChanged { value in
                let h = abs(value.translation.width)
                let v = abs(value.translation.height)
                // Only track horizontal movement for swipe
                guard h > v * 1.8 else { return }
                if !isDragging {
                    isDragging = true
                    dragAnchorOffset = dragOffset
                }
                swipeJustOpened = true
                let newOffset = dragAnchorOffset + value.translation.width
                dragOffset = max(-actionWidth, min(actionWidth, newOffset))
            }
            .onEnded { value in
                isDragging = false
                let h = abs(value.translation.width)
                let v = value.translation.height
                let absV = abs(v)

                // Upward flick: clearly vertical, upward, past threshold
                if v < -44 && absV > h * 1.8 {
                    withAnimation(AppAnimation.springSnappy) { dragOffset = 0 }
                    cycleNoteType()
                    return
                }

                // Horizontal swipe resolution
                guard h > absV * 1.5 else {
                    withAnimation(AppAnimation.springSnappy) { dragOffset = 0 }
                    return
                }
                withAnimation(AppAnimation.springSnappy) {
                    if dragOffset > revealThreshold / 2 {
                        dragOffset = actionWidth
                    } else if dragOffset < -(revealThreshold / 2) {
                        dragOffset = -actionWidth
                    } else {
                        dragOffset = 0
                        swipeJustOpened = false
                    }
                }
            }
    }

    private func cycleNoteType() {
        let order: [NoteType] = [.idea, .task, .note]
        let current = order.firstIndex(of: note.type) ?? 0
        let next = order[(current + 1) % order.count]
        flashedType = next
        withAnimation(.spring(response: 0.22, dampingFraction: 0.65)) {
            note.type = next
            showTypeFlash = true
        }
        HapticEngine.typeChange()
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 900_000_000)
            withAnimation(.easeOut(duration: 0.2)) { showTypeFlash = false }
        }
    }
}

// MARK: - FilterChips

struct FilterChips: View {
    @Binding var selected: FilterType

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(FilterType.allCases, id: \.self) { type in
                    chipButton(for: type)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 6)
        }
        .fixedSize(horizontal: false, vertical: true)
        .mask(
            HStack(spacing: 0) {
                Rectangle()
                LinearGradient(
                    colors: [.black, .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: 40)
            }
        )
    }

    private func chipButton(for type: FilterType) -> some View {
        let isActive = selected == type
        return Button {
            withAnimation(AppAnimation.springSnappy) { selected = type }
        } label: {
            Text(type.label)
                .appFont(11, .medium, relativeTo: .caption2)
                .tracking(0.3)
                .textCase(.uppercase)
                .foregroundStyle(isActive ? AppColors.onAccent : AppColors.secondaryText)
                .padding(.horizontal, 10)
                .frame(height: 28)
                .background(
                    isActive
                        ? AnyShapeStyle(LinearGradient(
                            colors: [AppColors.ctaTop, AppColors.ctaBottom],
                            startPoint: .top, endPoint: .bottom))
                        : AnyShapeStyle(AppColors.ink.opacity(0.06))
                )
                .clipShape(Capsule())
                .overlay(
                    Capsule().stroke(AppColors.ink.opacity(isActive ? 0 : 0.04), lineWidth: 0.5)
                )
        }
        .buttonStyle(PressStyle())
        .accessibilityLabel(type.label)
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }
}

// MARK: - CaptureBar

private let capturePlaceholders = [
    "anything on your mind…",
    "say it out loud.",
    "what's the residue?",
    "leave it here. come back later.",
]

private let stressPlaceholders = [
    "let it out.",
    "no filter needed.",
    "what's weighing on you?",
    "it's safe here.",
]

struct CaptureBarView: View {
    @Binding var text: String
    var onSubmit: () -> Void
    var staticPlaceholder: String? = nil
    var savingToLibrary: Bool = false
    var urlDetected: Bool = false
    var voiceManager: VoiceCaptureManager? = nil
    var stressMode: Bool = false
    /// Flips to request keyboard focus (e.g. from a widget deep link).
    var focusTrigger: Bool = false
    var onFocusHandled: () -> Void = {}

    @FocusState private var focused: Bool
    @State private var placeholderIndex = Int.random(in: 0..<capturePlaceholders.count)
    @State private var recordingPulse = false
    @State private var submitScale: CGFloat = 1.0

    private var placeholder: String {
        if let s = staticPlaceholder { return s }
        if stressMode { return stressPlaceholders[placeholderIndex % stressPlaceholders.count] }
        return capturePlaceholders[placeholderIndex]
    }

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 10) {
                if text.isEmpty && !savingToLibrary, let voiceManager {
                    micButton(voiceManager)
                        .transition(.scale(scale: 0.7).combined(with: .opacity))
                        .animation(.spring(response: 0.22, dampingFraction: 0.7), value: text.isEmpty)
                }

                ZStack(alignment: .leading) {
                    if text.isEmpty {
                        Text(savingToLibrary ? "saving to library..." : placeholder)
                            .appFont(15, .light, relativeTo: .body)
                            .tracking(-0.15)
                            .foregroundStyle(stressMode && !savingToLibrary
                                ? AppColors.secondaryText
                                : AppColors.tertiaryText)
                            .id(savingToLibrary ? "saving" : "placeholder")
                            .transition(.opacity)
                            .animation(.easeInOut(duration: 0.2), value: savingToLibrary)
                    }

                    TextField("", text: $text, axis: .vertical)
                        .appFont(15, .light, relativeTo: .body)
                        .tracking(-0.15)
                        .lineLimit(1...4)
                        .foregroundStyle(AppColors.primaryText)
                        .tint(AppColors.primaryText)
                        .focused($focused)
                        .onSubmit(onSubmit)
                }

                if !text.isEmpty {
                    Button(action: handleSubmit) {
                        ZStack {
                            LinearGradient(
                                colors: [AppColors.ctaTop, AppColors.ctaBottom],
                                startPoint: .top, endPoint: .bottom
                            )
                            Image(systemName: "arrow.up")
                                .appFont(13, .semibold, relativeTo: .subheadline)
                                .foregroundStyle(AppColors.onAccent)
                        }
                        .frame(width: 32, height: 32)
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.18), radius: 5, y: 2)
                        .scaleEffect(submitScale)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("capture")
                    .accessibilityHint("saves your thought")
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
                    .animation(.spring(response: 0.22, dampingFraction: 0.7), value: text.isEmpty)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(minHeight: 52)
            // Liquid Glass — the capture bar is floating chrome above content,
            // the one place glass belongs (HIG). Gated + Reduce-Transparency fallback.
            .glassChrome(in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                if stressMode {
                    LinearGradient(
                        colors: [Color(red: 0.47, green: 0.67, blue: 1.0).opacity(0.06), .clear],
                        startPoint: .leading, endPoint: .trailing
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .allowsHitTesting(false)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(
                        voiceManager?.isRecording == true
                            ? AppColors.ink.opacity(recordingPulse ? 0.55 : 0.22)
                            : Color.clear,
                        lineWidth: voiceManager?.isRecording == true ? 1.5 : 0
                    )
                    .animation(AppAnimation.springGentle, value: recordingPulse)
            )
            .shadow(color: .black.opacity(0.10), radius: 14, y: 4)

            if urlDetected && !text.isEmpty {
                Text("saving to library")
                    .appFont(11, .light, relativeTo: .caption2)
                    .tracking(-0.05)
                    .foregroundStyle(AppColors.tertiaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)
                    .transition(.opacity)
            }

            if let err = voiceManager?.errorMessage {
                Text(err)
                    .appFont(12, .light, relativeTo: .caption)
                    .tracking(-0.1)
                    .foregroundStyle(AppColors.tertiaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 4)
                    .transition(.opacity)
            }
        }
        .onChange(of: voiceManager?.isRecording ?? false) { _, recording in
            if recording {
                withAnimation(AppAnimation.springGentle.repeatForever(autoreverses: true)) {
                    recordingPulse = true
                }
            } else {
                withAnimation(AppAnimation.springSnappy) { recordingPulse = false }
            }
        }
        .onChange(of: voiceManager?.transcribedText ?? "") { _, newText in
            if !newText.isEmpty { text = newText }
        }
        .onChange(of: focusTrigger) { _, trigger in
            if trigger {
                focused = true
                onFocusHandled()
            }
        }
        .onAppear {
            if focusTrigger {
                focused = true
                onFocusHandled()
            }
        }
    }

    private func handleSubmit() {
        // Ignore whitespace-only input — don't animate the button away for nothing.
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        HapticEngine.submit()
        withAnimation(.spring(response: 0.18, dampingFraction: 0.55)) {
            submitScale = 1.15
        }
        withAnimation(.easeIn(duration: 0.14).delay(0.1)) {
            submitScale = 0.0
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 160_000_000)
            submitScale = 1.0
            onSubmit()
        }
    }

    @ViewBuilder
    private func micButton(_ manager: VoiceCaptureManager) -> some View {
        ZStack {
            Circle()
                .fill(manager.isRecording
                      ? AnyShapeStyle(LinearGradient(colors: [AppColors.ctaTop, AppColors.ctaBottom], startPoint: .top, endPoint: .bottom))
                      : AnyShapeStyle(AppColors.ink.opacity(0.06)))
                .frame(width: 32, height: 32)
            Image(systemName: manager.isRecording ? "mic.fill" : "mic")
                .font(.system(size: 13, weight: manager.isRecording ? .semibold : .light))
                .foregroundStyle(manager.isRecording ? AppColors.onAccent : AppColors.primaryText)
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !manager.isRecording { manager.startRecording() }
                }
                .onEnded { _ in
                    manager.stopRecording()
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 150_000_000)
                        if !manager.transcribedText.isEmpty {
                            text = manager.transcribedText
                            manager.clearTranscription()
                        }
                    }
                }
        )
    }
}
