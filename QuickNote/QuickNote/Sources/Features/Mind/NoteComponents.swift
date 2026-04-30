// NoteComponents.swift — NoteCard, Badge, CatIcon, FilterChips, CaptureBarView

import SwiftUI

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
        }
    }
}

// MARK: - Badge

struct NoteBadge: View {
    let kind: NoteType

    var body: some View {
        HStack(spacing: 5) {
            CatIcon(kind: kind, size: 11)
            Text(kind.rawValue)
                .font(.system(size: 10.5, weight: .medium))
                .tracking(0.8)
                .textCase(.uppercase)
        }
        .foregroundStyle(AppColors.primaryText)
        .padding(.horizontal, 9)
        .frame(height: 22)
        .background(Color(hex: "0A0A0B").opacity(0.04))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Color(hex: "0A0A0B").opacity(0.07), lineWidth: 0.5))
    }
}

// MARK: - NoteCard

struct NoteCard: View {
    let note: Note
    var onTap: () -> Void = {}
    var onArchive: () -> Void = {}
    var onDelete: () -> Void = {}

    @State private var dragOffset: CGFloat = 0
    @State private var showDeleteAlert = false

    private let actionWidth: CGFloat = 76
    private let revealThreshold: CGFloat = 55
    private var fullReveal: CGFloat { actionWidth * 2 }

    private var relativeTime: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: note.createdAt, relativeTo: Date())
    }

    private var subtitle: String {
        if note.type == .task && !note.tasks.isEmpty {
            let c = note.tasks.count
            return "\(c) action item\(c == 1 ? "" : "s") extracted"
        } else if !note.tags.isEmpty {
            return "tagged · \(note.tags.prefix(3).joined(separator: ", "))"
        }
        return ""
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            if dragOffset < -8 {
                HStack(spacing: 0) {
                    archiveButton
                    deleteButton
                }
                .frame(width: fullReveal)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }

            cardFace
                .offset(x: dragOffset)
                .gesture(swipeGesture)
                .onTapGesture {
                    if dragOffset < 0 {
                        withAnimation(AppAnimation.springSnappy) { dragOffset = 0 }
                    } else {
                        onTap()
                    }
                }
        }
        .alert("Delete note?", isPresented: $showDeleteAlert) {
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

    private var archiveButton: some View {
        Button {
            withAnimation(AppAnimation.springFluid) { dragOffset = 0 }
            onArchive()
        } label: {
            VStack(spacing: 4) {
                Image(systemName: "archivebox")
                    .font(.system(size: 15, weight: .light))
                Text("archive")
                    .font(.system(size: 10, weight: .medium))
                    .tracking(0.3)
                    .textCase(.uppercase)
            }
            .foregroundStyle(AppColors.primaryText)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(hex: "0A0A0B").opacity(0.06))
        }
        .buttonStyle(.plain)
        .frame(width: actionWidth)
    }

    private var deleteButton: some View {
        Button { showDeleteAlert = true } label: {
            VStack(spacing: 4) {
                Image(systemName: "trash")
                    .font(.system(size: 15, weight: .light))
                Text("delete")
                    .font(.system(size: 10, weight: .medium))
                    .tracking(0.3)
                    .textCase(.uppercase)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppColors.destructive)
        }
        .buttonStyle(.plain)
        .frame(width: actionWidth)
    }

    private var cardFace: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                NoteBadge(kind: note.type)
                Spacer()
                Text(relativeTime)
                    .font(.system(size: 12, weight: .light))
                    .tracking(-0.1)
                    .foregroundStyle(AppColors.tertiaryText)
            }

            Text(note.displayText ?? note.rawText)
                .font(.system(size: 15, weight: .light))
                .tracking(-0.15)
                .lineSpacing(6)
                .foregroundStyle(AppColors.primaryText)
                .fixedSize(horizontal: false, vertical: true)

            if !subtitle.isEmpty {
                Text(subtitle)
                    .font(.system(size: 12.5, weight: .light))
                    .tracking(-0.1)
                    .foregroundStyle(AppColors.secondaryText)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.6), lineWidth: 0.5)
        )
    }

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 10, coordinateSpace: .local)
            .onChanged { value in
                let h = abs(value.translation.width)
                let v = abs(value.translation.height)
                guard h > v * 1.1 else { return }
                let raw = dragOffset == 0
                    ? min(0, value.translation.width)
                    : min(0, dragOffset + value.translation.width)
                dragOffset = max(raw, -fullReveal)
            }
            .onEnded { value in
                let h = abs(value.translation.width)
                let v = abs(value.translation.height)
                guard h > v else { return }
                withAnimation(AppAnimation.springSnappy) {
                    if value.translation.width < -revealThreshold {
                        dragOffset = -fullReveal
                    } else if value.translation.width > revealThreshold / 2 {
                        dragOffset = 0
                    } else {
                        dragOffset = dragOffset < -revealThreshold ? -fullReveal : 0
                    }
                }
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
        .background(
            LinearGradient(
                stops: [
                    .init(color: Color(hex: "F0F2F4").opacity(0.92), location: 0),
                    .init(color: Color(hex: "F0F2F4").opacity(0.78), location: 0.7),
                    .init(color: Color(hex: "F0F2F4").opacity(0.00), location: 1),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .background(.ultraThinMaterial)
        )
    }

    private func chipButton(for type: FilterType) -> some View {
        let isActive = selected == type
        return Button {
            withAnimation(AppAnimation.springSnappy) { selected = type }
        } label: {
            Text(type.label)
                .font(.system(size: 11, weight: .medium))
                .tracking(0.3)
                .textCase(.uppercase)
                .foregroundStyle(isActive ? .white : AppColors.secondaryText)
                .padding(.horizontal, 10)
                .frame(height: 28)
                .background(
                    isActive
                        ? AnyShapeStyle(LinearGradient(
                            colors: [Color(hex: "1a1a1d"), .black],
                            startPoint: .top, endPoint: .bottom))
                        : AnyShapeStyle(Color(hex: "0A0A0B").opacity(0.06))
                )
                .clipShape(Capsule())
                .overlay(
                    Capsule().stroke(Color(hex: "0A0A0B").opacity(isActive ? 0 : 0.04), lineWidth: 0.5)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - CaptureBar

private let capturePlaceholders = [
    "anything on your mind…",
    "say it out loud.",
    "what's the residue?",
    "leave it here. come back later.",
]

struct CaptureBarView: View {
    @Binding var text: String
    var onSubmit: () -> Void
    var staticPlaceholder: String? = nil
    var savingToLibrary: Bool = false
    var voiceManager: VoiceCaptureManager? = nil

    @FocusState private var focused: Bool
    @State private var placeholderIndex = 0
    @State private var recordingPulse = false

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 10) {
                // Mic button — left, visible when text is empty and not saving
                if text.isEmpty && !savingToLibrary, let voiceManager {
                    micButton(voiceManager)
                        .transition(.scale(scale: 0.7).combined(with: .opacity))
                        .animation(.spring(response: 0.22, dampingFraction: 0.7), value: text.isEmpty)
                }

                ZStack(alignment: .leading) {
                    if text.isEmpty {
                        Text(savingToLibrary
                             ? "saving to library..."
                             : (staticPlaceholder ?? capturePlaceholders[placeholderIndex]))
                            .font(.system(size: 15, weight: .light))
                            .tracking(-0.15)
                            .foregroundStyle(AppColors.tertiaryText)
                            .id(savingToLibrary ? "saving" : "\(placeholderIndex)")
                            .transition(.opacity)
                            .animation(.easeInOut(duration: 0.36), value: placeholderIndex)
                            .animation(.easeInOut(duration: 0.2), value: savingToLibrary)
                    }

                    TextField("", text: $text, axis: .vertical)
                        .font(.system(size: 15, weight: .light))
                        .tracking(-0.15)
                        .lineLimit(1...4)
                        .foregroundStyle(AppColors.primaryText)
                        .tint(AppColors.primaryText)
                        .focused($focused)
                        .onSubmit(onSubmit)
                }

                if !text.isEmpty {
                    Button(action: onSubmit) {
                        ZStack {
                            LinearGradient(
                                colors: [Color(hex: "1a1a1d"), .black],
                                startPoint: .top, endPoint: .bottom
                            )
                            Image(systemName: "arrow.up")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                        .frame(width: 32, height: 32)
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.18), radius: 5, y: 2)
                    }
                    .buttonStyle(.plain)
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
                    .animation(.spring(response: 0.22, dampingFraction: 0.7), value: text.isEmpty)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(minHeight: 52)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(
                        voiceManager?.isRecording == true
                            ? Color(hex: "0A0A0B").opacity(recordingPulse ? 0.55 : 0.22)
                            : Color.white.opacity(0.6),
                        lineWidth: voiceManager?.isRecording == true ? 1.5 : 0.5
                    )
                    .animation(AppAnimation.springGentle, value: recordingPulse)
            )

            // Voice error message
            if let err = voiceManager?.errorMessage {
                Text(err)
                    .font(.system(size: 12, weight: .light))
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
            if !newText.isEmpty {
                text = newText
            }
        }
        .task(id: staticPlaceholder) {
            guard staticPlaceholder == nil else { return }
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 4_200_000_000)
                guard !Task.isCancelled else { return }
                placeholderIndex = (placeholderIndex + 1) % capturePlaceholders.count
            }
        }
    }

    @ViewBuilder
    private func micButton(_ manager: VoiceCaptureManager) -> some View {
        ZStack {
            Circle()
                .fill(manager.isRecording
                      ? AnyShapeStyle(LinearGradient(colors: [Color(hex: "1a1a1d"), .black], startPoint: .top, endPoint: .bottom))
                      : AnyShapeStyle(Color(hex: "0A0A0B").opacity(0.06)))
                .frame(width: 32, height: 32)
            Image(systemName: manager.isRecording ? "mic.fill" : "mic")
                .font(.system(size: 13, weight: manager.isRecording ? .semibold : .light))
                .foregroundStyle(manager.isRecording ? Color.white : AppColors.primaryText)
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !manager.isRecording { manager.startRecording() }
                }
                .onEnded { _ in
                    manager.stopRecording()
                    // Small delay so transcription task can finalize
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
