// MindView.swift — the primary surface (inbox + overlays)

import SwiftUI
import SwiftData

struct MindView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Note.createdAt, order: .reverse) private var allNotes: [Note]
    @Query(sort: \Link.createdAt, order: .reverse) private var savedLinks: [Link]

    @State private var processor = NoteProcessor()
    @State private var voiceManager = VoiceCaptureManager()
    @State private var showDateFilter = false

    private var displayedLinks: [Link] {
        savedLinks.isEmpty ? Link.samples : savedLinks
    }

    private var availableTags: [String] {
        Array(Set(allNotes.flatMap { $0.tags })).sorted()
    }

    private var filteredNotes: [Note] {
        allNotes.filter { note in
            guard appState.filter.matches(note) else { return false }
            if appState.mindDateFilter != .none {
                guard appState.mindDateFilter.matches(note.createdAt,
                    customStart: appState.mindCustomStart,
                    customEnd: appState.mindCustomEnd) else { return false }
            }
            if let tag = appState.mindTagFilter {
                guard note.tags.contains(tag) else { return false }
            }
            return true
        }
    }

    private var shouldShowDigest: Bool {
        let cal = Calendar.current
        let now = Date()
        return cal.component(.weekday, from: now) == 1 &&
               cal.component(.hour, from: now) >= 18
    }

    var body: some View {
        ZStack {
            WallpaperView()
            mainContent
            floatingBar

            if appState.stage == .processing {
                ProcessingOverlay()
            }

            if appState.stage == .detail, let note = appState.activeNote {
                NoteDetailSheet(
                    note: note,
                    onClose: {
                        withAnimation(AppAnimation.springFluid) {
                            appState.stage = .inbox
                            appState.activeNote = nil
                        }
                    },
                    onArchive: { archiveNote(note) },
                    onDelete: { deleteNote(note) }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            if appState.isShowingDigestDetail {
                DigestDetailSheet(allNotes: allNotes) {
                    withAnimation(AppAnimation.springFluid) { appState.isShowingDigestDetail = false }
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(AppAnimation.springFluid, value: appState.stage)
        .animation(AppAnimation.springFluid, value: appState.isShowingDigestDetail)
    }

    // MARK: - Main layout

    @ViewBuilder
    private var mainContent: some View {
        VStack(spacing: 0) {
            navRow
            titleBlock
            FilterChips(selected: Binding(
                get: { appState.filter },
                set: { appState.filter = $0 }
            ))
            secondaryFilterRow
            noteList
        }
    }

    // MARK: - Date + Tag secondary filter row

    @ViewBuilder
    private var secondaryFilterRow: some View {
        let hasTags = !availableTags.isEmpty
        let hasActiveFilters = appState.mindDateFilter != .none || appState.mindTagFilter != nil
        if hasTags || hasActiveFilters {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    // Date filter chip
                    dateFilterChip

                    // Tag chips
                    ForEach(availableTags, id: \.self) { tag in
                        tagChip(tag, isActive: appState.mindTagFilter == tag) {
                            withAnimation(AppAnimation.springSnappy) {
                                appState.mindTagFilter = appState.mindTagFilter == tag ? nil : tag
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
            .padding(.bottom, 10)
        }
    }

    private var dateFilterChip: some View {
        let isActive = appState.mindDateFilter != .none
        return Button {
            showDateFilter = true
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "calendar")
                    .font(.system(size: 9, weight: .medium))
                Text(appState.mindDateFilter.label)
                    .font(.system(size: 10.5, weight: .medium))
                    .tracking(0.3)
                    .textCase(.uppercase)
                if isActive {
                    Button {
                        withAnimation(AppAnimation.springSnappy) { appState.mindDateFilter = .none }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 8, weight: .bold))
                    }
                    .buttonStyle(.plain)
                }
            }
            .foregroundStyle(isActive ? .white : AppColors.secondaryText)
            .padding(.horizontal, 10)
            .frame(height: 26)
            .background(
                isActive
                    ? AnyShapeStyle(LinearGradient(colors: [Color(hex: "1a1a1d"), .black], startPoint: .top, endPoint: .bottom))
                    : AnyShapeStyle(Color(hex: "6B7280").opacity(0.09))
            )
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Color(hex: "6B7280").opacity(isActive ? 0 : 0.15), lineWidth: 0.75))
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showDateFilter) {
            DateFilterSheet(
                option: Binding(get: { appState.mindDateFilter }, set: { appState.mindDateFilter = $0 }),
                customStart: Binding(get: { appState.mindCustomStart }, set: { appState.mindCustomStart = $0 }),
                customEnd: Binding(get: { appState.mindCustomEnd }, set: { appState.mindCustomEnd = $0 }),
                onDismiss: { showDateFilter = false }
            )
            .presentationDetents([.medium])
            .presentationBackground(Color(hex: "F4F6F8"))
            .presentationDragIndicator(.hidden)
        }
    }

    // MARK: - Nav row

    private var navRow: some View {
        HStack {
            MarkGlyph(size: 22, strokeWidth: 1.4)

            Spacer()

            Button {
                withAnimation(AppAnimation.springFluid) { appState.stage = .library }
            } label: {
                HStack(spacing: 8) {
                    libraryStackIcon
                    Text("library")
                        .font(.system(size: 13, weight: .regular))
                        .tracking(-0.1)
                        .foregroundStyle(AppColors.primaryText)
                    Text("\(displayedLinks.count)")
                        .font(.system(size: 10.5, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(AppColors.primaryText)
                        .padding(.horizontal, 5)
                        .frame(minWidth: 18, minHeight: 18)
                        .background(AppColors.accentBlue)
                        .clipShape(Capsule())
                }
                .padding(.leading, 10)
                .padding(.trailing, 12)
                .frame(height: 32)
                .background(Color(hex: "0A0A0B").opacity(0.06))
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Color(hex: "0A0A0B").opacity(0.04), lineWidth: 0.5))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .frame(height: 44)
    }

    private var libraryStackIcon: some View {
        Canvas { ctx, sz in
            let s = sz.width / 14
            for y: CGFloat in [2.5, 6.0, 9.5] {
                let rect = CGRect(x: 2*s, y: y*s, width: 10*s, height: 2.2*s)
                let p = Path(roundedRect: rect, cornerRadius: 0.6*s)
                ctx.stroke(p, with: .color(AppColors.primaryText), lineWidth: 1.1)
            }
        }
        .frame(width: 14, height: 14)
    }

    // MARK: - Title block

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("good morning.")
                .font(.system(size: 12, weight: .light))
                .tracking(-0.05)
                .foregroundStyle(AppColors.tertiaryText)

            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text("mind")
                    .font(.system(size: 34, weight: .heavy))
                    .tracking(-1)
                    .foregroundStyle(AppColors.primaryText)

                Text(" · \(filteredNotes.count) thought\(filteredNotes.count == 1 ? "" : "s")")
                    .font(.system(size: 12, weight: .light))
                    .tracking(-0.1)
                    .foregroundStyle(AppColors.tertiaryText)
                    .padding(.leading, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 4)
        .padding(.bottom, 18)
    }

    // MARK: - Note list

    private var noteList: some View {
        Group {
            if filteredNotes.isEmpty && !shouldShowDigest {
                emptyNoteList
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        if shouldShowDigest && appState.filter == .all {
                            DigestCard(allNotes: allNotes) {
                                withAnimation(AppAnimation.springFluid) { appState.isShowingDigestDetail = true }
                            }
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }

                        ForEach(Array(filteredNotes.enumerated()), id: \.element.id) { i, note in
                            NoteCard(
                                note: note,
                                onTap: {
                                    appState.activeNote = note
                                    withAnimation(AppAnimation.springFluid) { appState.stage = .detail }
                                },
                                onArchive: { archiveNote(note) },
                                onDelete: { deleteNote(note) }
                            )
                            .transition(.opacity.combined(with: .move(edge: .top)))
                            .animation(
                                AppAnimation.springFluid.delay(Double(i) * 0.04),
                                value: filteredNotes.count
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 140)
                }
                .mask(noteListMask)
            }
        }
    }

    private var noteListMask: some View {
        LinearGradient(
            stops: [
                .init(color: .clear, location: 0),
                .init(color: .black, location: 0.04),
                .init(color: .black, location: 0.80),
                .init(color: .clear, location: 1.0),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var emptyNoteList: some View {
        VStack {
            Spacer()
            let variant: MindEmptyState.EmptyVariant = allNotes.isEmpty
                ? .first
                : appState.filter == .all ? .inbox : .filter(appState.filter)
            MindEmptyState(variant: variant)
            Spacer()
        }
    }

    // MARK: - Floating bar

    private var floatingBar: some View {
        VStack(spacing: 0) {
            Spacer()

            LibraryToast(isVisible: appState.toastVisible) {
                withAnimation(AppAnimation.springFluid) {
                    appState.toastVisible = false
                    appState.stage = .library
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)

            CaptureBarView(
                text: Binding(get: { appState.captureText }, set: { appState.captureText = $0 }),
                onSubmit: submit,
                savingToLibrary: appState.isSavingToLibrary,
                voiceManager: voiceManager
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 36)
        }
    }

    // MARK: - Submit logic

    private func submit() {
        let text = appState.captureText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        appState.captureText = ""

        if isURL(text) {
            let link = Link(
                urlString: text,
                title: text,
                host: extractHost(from: text),
                kind: LinkKind.detect(from: text)
            )
            withAnimation { appState.isSavingToLibrary = true }
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 900_000_000)
                modelContext.insert(link)
                withAnimation { appState.isSavingToLibrary = false }
                withAnimation(AppAnimation.springFluid) { appState.toastVisible = true }
                try? await Task.sleep(nanoseconds: 2_400_000_000)
                withAnimation(AppAnimation.springFluid) { appState.toastVisible = false }
            }
            return
        }

        withAnimation(AppAnimation.springFluid) { appState.stage = .processing }

        let proc = processor
        Task {
            do {
                let note = try await proc.createNote(from: text)
                await MainActor.run {
                    withAnimation(AppAnimation.springFluid) {
                        modelContext.insert(note)
                        appState.stage = .inbox
                    }
                }
            } catch {
                await MainActor.run {
                    withAnimation(AppAnimation.springFluid) { appState.stage = .inbox }
                }
            }
        }
    }

    // MARK: - Note actions

    private func archiveNote(_ note: Note) {
        withAnimation(AppAnimation.springFluid) {
            if appState.activeNote?.id == note.id {
                appState.stage = .inbox
                appState.activeNote = nil
            }
            note.isArchived = true
        }
    }

    private func deleteNote(_ note: Note) {
        withAnimation(AppAnimation.springFluid) {
            if appState.activeNote?.id == note.id {
                appState.stage = .inbox
                appState.activeNote = nil
            }
            modelContext.delete(note)
        }
    }

    // MARK: - Shared chip builder

    private func tagChip(_ label: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text("#\(label)")
                .font(.system(size: 10.5, weight: .medium))
                .tracking(0.2)
                .foregroundStyle(isActive ? .white : AppColors.secondaryText)
                .padding(.horizontal, 10)
                .frame(height: 26)
                .background(
                    isActive
                        ? AnyShapeStyle(LinearGradient(colors: [Color(hex: "1a1a1d"), .black], startPoint: .top, endPoint: .bottom))
                        : AnyShapeStyle(Color(hex: "6B7280").opacity(0.09))
                )
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Color(hex: "6B7280").opacity(isActive ? 0 : 0.15), lineWidth: 0.75))
        }
        .buttonStyle(.plain)
    }

    // MARK: - URL helpers

    private func isURL(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        // Only route to Library if the ENTIRE input is a URL/link — not incidental mentions
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return false
        }
        let nsText = trimmed as NSString
        let range = NSRange(location: 0, length: nsText.length)
        guard let match = detector.firstMatch(in: trimmed, range: range) else { return false }
        // Match must span (nearly) the whole string and not be an email address
        let matchedString = nsText.substring(with: match.range)
        let coversMostOfInput = match.range.length >= Int(Double(nsText.length) * 0.85)
        let isEmail = matchedString.contains("@")
        return coversMostOfInput && !isEmail
    }

    private func extractHost(from url: String) -> String {
        guard let parsed = URL(string: url.hasPrefix("http") ? url : "https://\(url)"),
              let host = parsed.host else { return url }
        return host.replacingOccurrences(of: "www.", with: "")
    }
}
