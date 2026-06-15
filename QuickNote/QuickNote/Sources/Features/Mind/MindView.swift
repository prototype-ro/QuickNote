// MindView.swift — the primary surface (inbox + overlays)

import SwiftUI
import SwiftData

struct MindView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(sort: \Note.createdAt, order: .reverse) private var allNotes: [Note]
    @Query(sort: \Link.createdAt, order: .reverse) private var savedLinks: [Link]

    @State private var processor = NoteProcessor()
    @State private var voiceManager = VoiceCaptureManager()
    @State private var captureURLDetected = false
    @State private var repeatCounts: [UUID: Int] = [:]
    @State private var showSortSheet = false
    @State private var logoPulse = false
    @State private var latestNoteID: UUID? = nil
    @State private var showFirstNoteCeremony = false
    @FocusState private var searchFocused: Bool

    private var displayedLinks: [Link] { savedLinks }

    private var timeGreeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12:  return "good morning."
        case 12..<17: return "good afternoon."
        case 17..<21: return "good evening."
        default:      return "good night."
        }
    }

    private var availableTags: [String] {
        Array(Set(allNotes.flatMap { $0.tags })).sorted()
    }

    private var filteredNotes: [Note] {
        let base = allNotes.filter { note in
            guard appState.filter.matches(note) else { return false }
            if appState.mindDateFilter != .none {
                guard appState.mindDateFilter.matches(note.createdAt,
                    customStart: appState.mindCustomStart,
                    customEnd: appState.mindCustomEnd) else { return false }
            }
            if let tag = appState.mindTagFilter {
                guard note.tags.contains(tag) else { return false }
            }
            let query = appState.mindSearchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if !query.isEmpty {
                let haystack = ([note.displayText ?? note.rawText, note.rawText, note.summary]
                    + note.tags + note.tasks).joined(separator: " ").lowercased()
                guard haystack.contains(query) else { return false }
            }
            return true
        }
        switch appState.mindSortOrder {
        case .newest: return base
        case .oldest: return base.reversed()
        case .byType: return base.sorted { $0.type.rawValue < $1.type.rawValue }
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

            if appState.isQuietHours {
                quietHoursContent
            } else {
                mainContent
            }

            floatingBar

            if appState.stage == .processing {
                ProcessingOverlay(capturedText: appState.capturedTextForProcessing)
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
                .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
            }

            if appState.isShowingDigestDetail {
                DigestDetailSheet(allNotes: allNotes, onClose: {
                    withAnimation(AppAnimation.springFluid) { appState.isShowingDigestDetail = false }
                }, onOpenNote: { note in
                    appState.isShowingDigestDetail = false
                    appState.activeNote = note
                    withAnimation(AppAnimation.springFluid) { appState.stage = .detail }
                })
                .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
            }

            if appState.isShowingSettings {
                SettingsView(notes: allNotes) {
                    withAnimation(AppAnimation.springFluid) { appState.isShowingSettings = false }
                }
                .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
            }

            if appState.isRecalling {
                RecallView(
                    notes: allNotes,
                    processor: processor,
                    onClose: {
                        withAnimation(AppAnimation.springFluid) { appState.isRecalling = false }
                    },
                    onOpenNote: { note in
                        appState.isRecalling = false
                        appState.activeNote = note
                        withAnimation(AppAnimation.springFluid) { appState.stage = .detail }
                    }
                )
                .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(AppAnimation.springFluid, value: appState.stage)
        .animation(AppAnimation.springFluid, value: appState.isShowingDigestDetail)
        .animation(AppAnimation.springFluid, value: appState.isRecalling)
        .animation(AppAnimation.springFluid, value: appState.isShowingSettings)
        .animation(AppAnimation.springFluid, value: appState.isQuietHours)
        .onChange(of: appState.stage) { _, newStage in
            // Don't let an echo linger and re-render stale after navigating away.
            if newStage != .inbox, appState.echoForNoteID != nil {
                appState.echoNote = nil
                appState.echoForNoteID = nil
            }
        }
        .simultaneousGesture(TapGesture().onEnded {
            // Skip while Recall is open — it owns the keyboard; firing here would
            // dismiss the query field the instant the user taps it.
            guard !appState.isRecalling else { return }
            UIApplication.shared.sendAction(
                #selector(UIResponder.resignFirstResponder),
                to: nil, from: nil, for: nil
            )
        })
        .onAppear {
            computePatterns(allNotes)
            detectStressMode(allNotes)
            backfillEmbeddings(allNotes)
            WidgetBridge.update(from: allNotes)
        }
        .onChange(of: allNotes.count) { old, new in
            computePatterns(allNotes)
            detectStressMode(allNotes)
            WidgetBridge.update(from: allNotes)
            if new > old {
                triggerLogoPulse()
                checkFirstNoteCeremony(old: old)
            }
        }
        .onChange(of: appState.captureText) { _, text in
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            withAnimation(.easeInOut(duration: 0.18)) {
                captureURLDetected = !trimmed.isEmpty && isURL(trimmed)
            }
        }
        .sheet(isPresented: Binding(
            get: { appState.isRecordingVoice },
            set: { appState.isRecordingVoice = $0 }
        )) {
            CaptureRecordingSheet { fileName, duration, waveform, drill in
                insertVoiceNote(fileName: fileName, duration: duration, waveform: waveform, drill: drill)
            }
            .presentationDetents([.height(380)])
            .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Main layout

    @ViewBuilder
    private var mainContent: some View {
        VStack(spacing: 0) {
            navRow
            titleBlock
            HStack(alignment: .center, spacing: 0) {
                FilterChips(selected: Binding(
                    get: { appState.filter },
                    set: { appState.filter = $0 }
                ))
                searchButton
                sortButton
            }
            .fixedSize(horizontal: false, vertical: true)
            .background(.ultraThinMaterial)
            if appState.isSearching { searchField }
            secondaryFilterRow
            AppColors.hairline
                .frame(height: 0.5)
                .frame(maxWidth: .infinity)
            noteList
        }
    }

    // MARK: - Quiet Hours

    @ViewBuilder
    private var quietHoursContent: some View {
        VStack {
            HStack {
                MarkGlyph(size: 22, strokeWidth: 1.4)
                    .scaleEffect(logoPulse ? 1.09 : 1.0)
                    .animation(.spring(response: 0.28, dampingFraction: 0.55), value: logoPulse)
                    .onLongPressGesture(minimumDuration: 0.5) { toggleQuietHours() }
                Spacer()
                Button {
                    toggleQuietHours()
                } label: {
                    Text("return")
                        .appFont(13, .regular, relativeTo: .subheadline)
                        .tracking(-0.1)
                        .foregroundStyle(AppColors.secondaryText)
                        .padding(.horizontal, 12)
                        .frame(height: 32)
                        .background(AppColors.ink.opacity(0.06))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(AppColors.ink.opacity(0.04), lineWidth: 0.5))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .frame(height: 44)

            Spacer()

            Text("quiet hours")
                .appFont(13, .light, relativeTo: .subheadline)
                .italic()
                .foregroundStyle(AppColors.tertiaryText)

            Spacer()
        }
    }

    // MARK: - Sort button

    private var sortButton: some View {
        HStack(spacing: 0) {
            AppColors.ink.opacity(0.08)
                .frame(width: 0.5, height: 20)
                .padding(.vertical, 8)

            Button {
                showSortSheet = true
            } label: {
                Image(systemName: "line.3.horizontal.decrease")
                    .appFont(13, .regular, relativeTo: .subheadline)
                    .foregroundStyle(appState.mindSortOrder == .newest
                                     ? AppColors.secondaryText
                                     : AppColors.primaryText)
                    .frame(width: 36, height: 36)
                    .background(appState.mindSortOrder == .newest
                                 ? AppColors.ink.opacity(0.04)
                                 : AppColors.ink.opacity(0.10))
                    .clipShape(Circle())
                    .overlay(Circle().stroke(AppColors.ink.opacity(0.06), lineWidth: 0.5))
            }
            .buttonStyle(.plain)
            .padding(.trailing, 12)
            .padding(.leading, 8)
        }
        .confirmationDialog("Sort by", isPresented: $showSortSheet, titleVisibility: .visible) {
            Button("Newest First") {
                withAnimation(AppAnimation.springSnappy) { appState.mindSortOrder = .newest }
            }
            Button("Oldest First") {
                withAnimation(AppAnimation.springSnappy) { appState.mindSortOrder = .oldest }
            }
            Button("Type") {
                withAnimation(AppAnimation.springSnappy) { appState.mindSortOrder = .byType }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: - Search

    private var searchButton: some View {
        Button {
            withAnimation(AppAnimation.springSnappy) {
                appState.isSearching.toggle()
                if !appState.isSearching { appState.mindSearchText = "" }
            }
            if appState.isSearching { searchFocused = true }
        } label: {
            Image(systemName: "magnifyingglass")
                .appFont(13, .regular, relativeTo: .subheadline)
                .foregroundStyle(appState.isSearching ? AppColors.primaryText : AppColors.secondaryText)
                .frame(width: 36, height: 36)
                .background(appState.isSearching
                            ? AppColors.ink.opacity(0.10)
                            : AppColors.ink.opacity(0.04))
                .clipShape(Circle())
                .overlay(Circle().stroke(AppColors.ink.opacity(0.06), lineWidth: 0.5))
        }
        .buttonStyle(.plain)
        .padding(.leading, 8)
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .appFont(13, .light, relativeTo: .subheadline)
                .foregroundStyle(AppColors.tertiaryText)
            TextField("search your thoughts…", text: Binding(
                get: { appState.mindSearchText },
                set: { appState.mindSearchText = $0 }
            ))
            .appFont(15, .light, relativeTo: .body)
            .tracking(-0.1)
            .foregroundStyle(AppColors.primaryText)
            .tint(AppColors.primaryText)
            .focused($searchFocused)
            .submitLabel(.search)
            if !appState.mindSearchText.isEmpty {
                Button {
                    appState.mindSearchText = ""
                    searchFocused = true
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(AppColors.tertiaryText)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(AppColors.ink.opacity(0.03))
        .overlay(alignment: .bottom) {
            AppColors.hairline.frame(height: 0.5)
        }
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    // MARK: - Secondary filter row

    @ViewBuilder
    private var secondaryFilterRow: some View {
        let hasActiveTagFilter = appState.mindTagFilter != nil
        if !availableTags.isEmpty || hasActiveTagFilter {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
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
            .fixedSize(horizontal: false, vertical: true)
            .padding(.vertical, 8)
        }
    }

    // MARK: - Nav row

    private var navRow: some View {
        HStack {
            MarkGlyph(size: 22, strokeWidth: 1.4)
                .scaleEffect(logoPulse ? 1.09 : 1.0)
                .animation(.spring(response: 0.28, dampingFraction: 0.55), value: logoPulse)
                .onLongPressGesture(minimumDuration: 0.5) { toggleQuietHours() }

            Spacer()

            Button {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                withAnimation(AppAnimation.springFluid) { appState.isRecalling = true }
            } label: {
                Image(systemName: "sparkle.magnifyingglass")
                    .appFont(14, .light, relativeTo: .subheadline)
                    .foregroundStyle(AppColors.primaryText)
                    .frame(width: 32, height: 32)
                    .background(AppColors.ink.opacity(0.06))
                    .clipShape(Circle())
                    .overlay(Circle().stroke(AppColors.ink.opacity(0.04), lineWidth: 0.5))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("recall")
            .accessibilityHint("search your thoughts by meaning")
            .padding(.trailing, 8)

            Button {
                withAnimation(AppAnimation.springFluid) { appState.stage = .library }
            } label: {
                HStack(spacing: 8) {
                    libraryStackIcon
                    Text("library")
                        .appFont(13, .regular, relativeTo: .subheadline)
                        .tracking(-0.1)
                        .foregroundStyle(AppColors.primaryText)
                }
                .padding(.leading, 10)
                .padding(.trailing, 12)
                .frame(height: 32)
                .background(AppColors.ink.opacity(0.06))
                .clipShape(Capsule())
                .overlay(Capsule().stroke(AppColors.ink.opacity(0.04), lineWidth: 0.5))
                .overlay(alignment: .topTrailing) {
                    Text("\(displayedLinks.count)")
                        .appFont(10.5, .semibold, relativeTo: .caption2)
                        .monospacedDigit()
                        .foregroundStyle(AppColors.primaryText)
                        .padding(.horizontal, 5)
                        .frame(minWidth: 18, minHeight: 18)
                        .background(AppColors.accentBlue)
                        .clipShape(Capsule())
                        .offset(x: 4, y: -4)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("library, \(displayedLinks.count) saved links")
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
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 4) {
                Text(timeGreeting)
                    .appFont(12, .light, relativeTo: .caption)
                    .tracking(-0.05)
                    .foregroundStyle(AppColors.tertiaryText)

                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    Text("mind")
                        .appFont(34, .heavy, relativeTo: .largeTitle)
                        .tracking(-1)
                        .foregroundStyle(AppColors.primaryText)

                    Text(" · \(filteredNotes.count) thought\(filteredNotes.count == 1 ? "" : "s")")
                        .appFont(12, .light, relativeTo: .caption)
                        .tracking(-0.1)
                        .foregroundStyle(AppColors.tertiaryText)
                        .padding(.leading, 2)
                        .contentTransition(reduceMotion ? .identity : .numericText())
                }
            }

            Spacer()

            Button {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                withAnimation(AppAnimation.springFluid) { appState.isShowingSettings = true }
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .appFont(14, .light, relativeTo: .subheadline)
                    .foregroundStyle(AppColors.secondaryText)
                    .frame(width: 32, height: 32)
                    .background(AppColors.ink.opacity(0.04))
                    .clipShape(Circle())
                    .overlay(Circle().stroke(AppColors.ink.opacity(0.04), lineWidth: 0.5))
            }
            .buttonStyle(.plain)
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
                            DigestCard(allNotes: allNotes, linkCount: displayedLinks.count) {
                                withAnimation(AppAnimation.springFluid) { appState.isShowingDigestDetail = true }
                            }
                            .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .top)))
                        }

                        ForEach(Array(filteredNotes.enumerated()), id: \.element.id) { i, note in
                            VStack(spacing: 4) {
                                NoteCard(
                                    note: note,
                                    repeatCount: repeatCounts[note.id] ?? 0,
                                    isNew: note.id == latestNoteID,
                                    onTap: {
                                        appState.activeNote = note
                                        withAnimation(AppAnimation.springFluid) { appState.stage = .detail }
                                    },
                                    onArchive: { archiveNote(note) },
                                    onDelete: { deleteNote(note) }
                                )
                                .inkReveal(active: note.id == latestNoteID)
                                .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .top)))
                                .animation(
                                    AppAnimation.springFluid.delay(Double(i) * 0.04),
                                    value: filteredNotes.count
                                )

                                // First note ceremony
                                if i == 0 && showFirstNoteCeremony {
                                    Text("your first thought.")
                                        .appFont(12, .light, relativeTo: .caption)
                                        .italic()
                                        .tracking(-0.05)
                                        .foregroundStyle(AppColors.tertiaryText)
                                        .frame(maxWidth: .infinity, alignment: .center)
                                        .transition(.opacity)
                                }

                                // Echo — a past note surfacing beneath the new one
                                if note.id == appState.echoForNoteID, let echo = appState.echoNote {
                                    EchoThread(note: echo) {
                                        appState.echoNote = nil
                                        appState.echoForNoteID = nil
                                        appState.activeNote = echo
                                        withAnimation(AppAnimation.springFluid) { appState.stage = .detail }
                                    }
                                    .transition(.opacity)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 140)
                }
                .scrollDismissesKeyboard(.immediately)
            }
        }
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

            HStack(alignment: .bottom, spacing: 10) {
                CaptureBarView(
                    text: Binding(get: { appState.captureText }, set: { appState.captureText = $0 }),
                    onSubmit: submit,
                    savingToLibrary: appState.isSavingToLibrary,
                    urlDetected: captureURLDetected,
                    voiceManager: voiceManager,
                    stressMode: appState.stressMode,
                    focusTrigger: appState.shouldFocusCapture,
                    onFocusHandled: { appState.shouldFocusCapture = false }
                )
                Button {
                    appState.isRecordingVoice = true
                } label: {
                    Image(systemName: "waveform")
                        .appFont(16, .regular, relativeTo: .body)
                        .foregroundStyle(AppColors.voiceAccent)
                        .frame(width: 44, height: 44)
                        .background(AppColors.voiceAccent.opacity(0.12))
                        .clipShape(Circle())
                        .overlay(Circle().stroke(AppColors.voiceAccent.opacity(0.2), lineWidth: 0.5))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("nova gravação")
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 36)
        }
    }

    // MARK: - Submit logic

    /// Inserts a finished voice recording as a `.voice` note. Body stays empty
    /// until the user transcribes it from the detail sheet.
    private func insertVoiceNote(fileName: String, duration: TimeInterval,
                                 waveform: [Float], drill: RoteiroDrill?) {
        let note = Note(rawText: "", type: .voice)
        note.audioFileName = fileName
        note.audioDuration = duration
        note.waveform = waveform
        note.drill = drill?.rawValue
        withAnimation(AppAnimation.springFluid) {
            latestNoteID = note.id
            modelContext.insert(note)
            HapticEngine.noteArrived()
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            latestNoteID = nil
        }
    }

    private func submit() {
        let text = appState.captureText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        appState.captureText = ""

        if isURL(text) {
            let kind = LinkKind.detect(from: text)
            let host = extractHost(from: text)
            let link = Link(urlString: text, title: host, host: host, kind: kind)
            withAnimation { appState.isSavingToLibrary = true }
            captureURLDetected = false
            // Ghost paste: insert immediately so card appears in Library at once
            modelContext.insert(link)
            Task { @MainActor in
                let meta = await fetchMetadataWithTimeout(urlString: text, kind: kind)
                if let title = meta.title, !title.isEmpty { link.title = title }
                if let thumb = meta.thumbnailURLString { link.thumbnailURL = thumb }
                if let author = meta.author { link.author = author }
                var downloadedThumb: Data? = nil
                if let thumb = meta.thumbnailURLString {
                    downloadedThumb = await LinkMetadataService.shared.imageData(from: thumb)
                    if let downloadedThumb { link.thumbnailData = downloadedThumb }
                }
                if var product = meta.product {
                    product.imageData = downloadedThumb ?? link.thumbnailData
                    link.product = product
                    link.kind = .product
                }
                withAnimation { appState.isSavingToLibrary = false }
                withAnimation(AppAnimation.springFluid) { appState.toastVisible = true }
                try? await Task.sleep(nanoseconds: 2_400_000_000)
                withAnimation(AppAnimation.springFluid) { appState.toastVisible = false }
            }
            return
        }

        // Store captured text for ProcessingOverlay display
        appState.capturedTextForProcessing = text
        withAnimation(AppAnimation.springFluid) { appState.stage = .processing }

        // Snapshot the prior corpus for echo retrieval before the new note lands.
        let priorCorpus = allNotes
        let proc = processor
        Task {
            let note = await proc.createNote(from: text)
            let embedded = EmbeddingService.shared.embed(note.embeddingInput)
            note.embedding = embedded.vector
            note.langCode = embedded.language
            await MainActor.run {
                withAnimation(AppAnimation.springFluid) {
                    latestNoteID = note.id
                    modelContext.insert(note)
                    appState.stage = .inbox
                    appState.capturedTextForProcessing = ""
                    HapticEngine.noteArrived()
                }
                surfaceEcho(for: note, among: priorCorpus)
                // Clear isNew flag after animation window
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 1_200_000_000)
                    latestNoteID = nil
                }
            }
        }
    }

    // MARK: - Echo at capture

    /// Cosine threshold an echo must clear to surface. High by design — silence
    /// is the default; a wrong echo costs more trust than a missing one.
    private static let echoThreshold: Double = 0.62

    /// If the freshly captured note is reflective and has a strong semantic
    /// neighbor in the prior corpus, surface that neighbor as a decaying echo.
    private func surfaceEcho(for note: Note, among corpus: [Note]) {
        guard note.type == .note || note.type == .idea, !note.embedding.isEmpty else { return }
        let candidates = corpus.filter {
            $0.id != note.id && !$0.isArchived &&
            ($0.type == .note || $0.type == .idea) &&
            $0.langCode == note.langCode  // never compare across embedding spaces
        }
        guard let match = SemanticIndex.bestMatch(
            to: note.embedding, among: candidates, threshold: Self.echoThreshold
        ) else { return }

        Task { @MainActor in
            // Let the ink reveal settle before the memory whispers in.
            try? await Task.sleep(nanoseconds: 550_000_000)
            withAnimation(.easeOut(duration: 0.5)) {
                appState.echoNote = match.note
                appState.echoForNoteID = note.id
            }
            HapticEngine.echo()
            // Decay if the user doesn't reach for it.
            try? await Task.sleep(nanoseconds: 6_000_000_000)
            guard appState.echoForNoteID == note.id else { return }
            withAnimation(.easeIn(duration: 0.6)) {
                appState.echoNote = nil
                appState.echoForNoteID = nil
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

    // MARK: - Quiet hours

    private func toggleQuietHours() {
        withAnimation(AppAnimation.springFluid) {
            appState.isQuietHours.toggle()
        }
    }

    // MARK: - Logo pulse

    private func triggerLogoPulse() {
        logoPulse = true
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 300_000_000)
            logoPulse = false
        }
    }

    // MARK: - First note ceremony

    private func checkFirstNoteCeremony(old: Int) {
        guard old == 0, !appState.firstNoteCeremonyShown else { return }
        appState.firstNoteCeremonyShown = true
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 600_000_000)
            withAnimation(.easeIn(duration: 0.3)) { showFirstNoteCeremony = true }
            try? await Task.sleep(nanoseconds: 2_800_000_000)
            withAnimation(.easeOut(duration: 0.4)) { showFirstNoteCeremony = false }
        }
    }

    // MARK: - Chip builder

    private func tagChip(_ label: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Pill(isActive: isActive) {
                Text("#\(label)")
                    .appFont(10.5, .medium, relativeTo: .caption2)
                    .tracking(0.2)
                    .foregroundStyle(isActive ? AppColors.onAccent : AppColors.secondaryText)
            }
        }
        .buttonStyle(PressStyle())
        .accessibilityLabel(label)
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }

    // MARK: - Embedding backfill

    /// Computes embeddings for any notes that lack one (existing corpus, or notes
    /// captured while the model was unavailable). On-device, idempotent.
    private func backfillEmbeddings(_ notes: [Note]) {
        guard EmbeddingService.shared.isAvailable else { return }
        let pending = notes.filter { $0.embedding.isEmpty }
        guard !pending.isEmpty else { return }
        Task { @MainActor in
            for note in pending {
                let embedded = EmbeddingService.shared.embed(note.embeddingInput)
                note.embedding = embedded.vector
                note.langCode = embedded.language
            }
        }
    }

    // MARK: - Pattern detection

    private func computePatterns(_ notes: [Note]) {
        let stopWords: Set<String> = [
            "the","a","an","is","it","in","on","at","to","and","or","but","not",
            "with","for","from","by","of","be","was","are","this","that","i","my",
            "me","we","he","she","they","you","do","did","will","can","have","has",
            "had","just","need","want","make","get","go","been","some","about"
        ]
        let cutoff = Date().addingTimeInterval(-30 * 24 * 60 * 60)
        let eligible = notes.filter {
            ($0.type == .task || $0.type == .note) && $0.createdAt >= cutoff && !$0.isArchived
        }
        // Build each note's word-set once (was rebuilt O(n²) times in the inner loop).
        let wordSets: [(id: UUID, words: Set<String>)] = eligible.compactMap { note in
            let words = Set(
                (note.displayText ?? note.rawText)
                    .lowercased()
                    .components(separatedBy: CharacterSet.alphanumerics.inverted)
                    .filter { $0.count >= 4 && !stopWords.contains($0) }
            )
            return words.isEmpty ? nil : (note.id, words)
        }
        var counts: [UUID: Int] = [:]
        for current in wordSets {
            let matchCount = wordSets.filter { other in
                other.id != current.id && current.words.intersection(other.words).count >= 2
            }.count
            if matchCount >= 2 { counts[current.id] = matchCount + 1 }
        }
        repeatCounts = counts
    }

    // MARK: - Stress mode detection (Pressure Valve)

    private func detectStressMode(_ notes: [Note]) {
        let stressWords: Set<String> = [
            "stressed","overwhelmed","anxious","worried","frustrated","hate","terrible",
            "awful","ugh","dread","exhausted","burnout","tired","angry","upset","panic",
            "scared","annoyed","irritated","helpless","hopeless","nervous","depressed"
        ]
        let cutoff = Date().addingTimeInterval(-7 * 24 * 60 * 60)
        let recent = notes.filter { $0.createdAt >= cutoff && !$0.isArchived }
        let stressCount = recent.filter { note in
            let words = (note.rawText).lowercased()
                .components(separatedBy: CharacterSet.alphanumerics.inverted)
            return words.contains { stressWords.contains($0) }
        }.count
        withAnimation(.easeInOut(duration: 0.4)) {
            appState.stressMode = stressCount >= 2
        }
    }

    // MARK: - URL helpers

    private func isURL(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return false
        }
        let nsText = trimmed as NSString
        let range = NSRange(location: 0, length: nsText.length)
        guard let match = detector.firstMatch(in: trimmed, range: range) else { return false }
        let matchedString = nsText.substring(with: match.range)
        let coversMostOfInput = match.range.length >= Int(Double(nsText.length) * 0.85)
        let isEmail = matchedString.contains("@")
        return coversMostOfInput && !isEmail
    }

    private func fetchMetadataWithTimeout(urlString: String, kind: LinkKind) async -> FetchedLinkMetadata {
        await withTaskGroup(of: FetchedLinkMetadata?.self) { group in
            group.addTask { await LinkMetadataService.shared.fetch(urlString: urlString, kind: kind) }
            group.addTask {
                do { try await Task.sleep(nanoseconds: 5_000_000_000) } catch {}
                return nil
            }
            for await value in group {
                group.cancelAll()
                return value ?? FetchedLinkMetadata()
            }
            return FetchedLinkMetadata()
        }
    }

    private func extractHost(from url: String) -> String {
        guard let parsed = URL(string: url.hasPrefix("http") ? url : "https://\(url)"),
              let host = parsed.host else { return url }
        return host.replacingOccurrences(of: "www.", with: "")
    }
}
