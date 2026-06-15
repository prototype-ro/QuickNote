// NoteDetailSheet.swift — bottom sheet for full note view

import SwiftUI
import SwiftData

struct NoteDetailSheet: View {
    let note: Note
    var onClose: () -> Void
    var onArchive: () -> Void
    var onDelete: () -> Void

    @Environment(AppState.self) private var appState
    @Environment(AudioPlayerService.self) private var audioPlayer
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(filter: #Predicate<Note> { !$0.isArchived }) private var allNotes: [Note]

    @State private var showDeleteAlert = false
    @State private var showEnhancer = false
    @State private var showTypePicker = false
    @State private var showAddTagField = false
    @State private var newTagText = ""
    @State private var relatedNoteIDs: [UUID] = []
    @State private var processor = NoteProcessor()
    @State private var isEnhancing = false
    @State private var sparkPulse = false
    @State private var isEditing = false
    @State private var editDraft = ""
    @State private var showDevelop = false
    @State private var showRevertConfirm = false
    @State private var sheetDragOffset: CGFloat = 0
    // Fix 8: flag to suppress animation during active drag
    @State private var isDragging = false
    // Calendar capture (Pro)
    @State private var showCalProPrompt = false
    @State private var addingEvent = false
    @State private var calError: String? = nil
    @State private var isTranscribing = false
    @State private var showReview = false
    @State private var transcribeError = false

    private var relatedNotes: [Note] {
        relatedNoteIDs.compactMap { id in allNotes.first { $0.id == id } }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            AppColors.ink.opacity(0.18)
                .ignoresSafeArea()
                .background(.ultraThinMaterial.opacity(0.3))
                .onTapGesture(perform: onClose)

            sheetContent
                .offset(y: sheetDragOffset)
                .animation(isDragging ? nil : AppAnimation.springFluid, value: sheetDragOffset)
                .transition(reduceMotion ? .opacity : .move(edge: .bottom))
        }
        .ignoresSafeArea()
        .fullScreenCover(isPresented: $showDevelop) {
            DevelopEditorView(note: note) { showDevelop = false }
        }
        .confirmationDialog("Revert to original?", isPresented: $showRevertConfirm, titleVisibility: .visible) {
            Button("Revert", role: .destructive) {
                note.displayText = nil
                note.enhancementMode = nil
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The AI-enhanced version will be removed.")
        }
        .alert("Delete this note?", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive, action: onDelete)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This cannot be undone.")
        }
        .confirmationDialog("Change type", isPresented: $showTypePicker, titleVisibility: .visible) {
            ForEach(NoteType.allCases.filter { $0 != .digest }, id: \.self) { type in
                Button(type.rawValue.capitalized) {
                    note.type = type
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .task {
            showReview = !(note.voiceReview ?? VoiceReview()).isEmpty
            relatedNoteIDs = (try? await processor.findRelated(for: note, allNotes: allNotes)) ?? []
        }
        .sheet(isPresented: $showCalProPrompt) {
            ProUpgradeSheet()
        }
    }

    // MARK: - Movie hero (media enrichment)

    @ViewBuilder
    private var movieHero: some View {
        if let media = note.media {
            VStack(alignment: .leading, spacing: 0) {
                if let data = media.posterData, let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 150)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .padding(.bottom, 12)
                }
                Text(media.title)
                    .appFont(18, .semibold, relativeTo: .title3)
                    .tracking(-0.3)
                    .foregroundStyle(AppColors.primaryText)
                if !media.metaLine.isEmpty {
                    Text(media.metaLine)
                        .appFont(12.5, .light, relativeTo: .caption)
                        .foregroundStyle(AppColors.secondaryText)
                        .padding(.top, 3)
                }
                if let overview = media.overview {
                    Text(overview)
                        .appFont(13, .light, relativeTo: .subheadline)
                        .lineSpacing(4)
                        .foregroundStyle(AppColors.secondaryText)
                        .padding(.top, 8)
                }
            }
        }
    }

    // MARK: - Voice hero (audio capture)

    @ViewBuilder
    private var voiceHero: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let file = note.audioFileName {
                PlayerPanel(fileName: file, peaks: note.waveform,
                            duration: note.audioDuration, player: audioPlayer)
            }

            Menu {
                Button("livre") { note.drill = nil }
                ForEach(RoteiroDrill.allCases) { d in
                    Button(d.label) { note.drill = d.rawValue }
                }
            } label: {
                let label = note.drill.flatMap { RoteiroDrill(rawValue: $0)?.label } ?? "+ marcar exercício"
                Text(label)
                    .appFont(13, .medium)
                    .foregroundStyle(note.drill != nil ? AppColors.voiceAccent : AppColors.secondaryText)
                    .padding(.vertical, 6).padding(.horizontal, 12)
                    .background(Capsule().fill((note.drill != nil ? AppColors.voiceAccent : AppColors.secondaryText).opacity(0.12)))
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("anotações").appFont(14, .medium).foregroundStyle(AppColors.secondaryText)
                TextEditor(text: Binding(get: { note.voiceAnnotation }, set: { note.voiceAnnotation = $0 }))
                    .appFont(16).frame(minHeight: 110).scrollContentBackground(.hidden).padding(10)
                    .background(CategoryTint.wash(.voice), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }

            if !note.isTranscribed && VoiceTranscriptionService.isAvailable {
                Button { Task { await transcribe() } } label: {
                    HStack(spacing: 6) {
                        if isTranscribing { ProgressView().controlSize(.small) }
                        else { Image(systemName: "sparkles") }
                        Text(isTranscribing ? "transcrevendo…" : "transcrever")
                    }
                    .appFont(15, .medium).foregroundStyle(AppColors.voiceAccent)
                }
                .buttonStyle(.plain)
                .disabled(isTranscribing)
            }
            if transcribeError {
                Text("não consegui transcrever — tente de novo")
                    .appFont(12).foregroundStyle(AppColors.secondaryText)
            }

            DisclosureGroup(isExpanded: $showReview) {
                ReviewEditor(review: Binding(
                    get: { note.voiceReview ?? VoiceReview() },
                    set: { note.voiceReview = $0.isEmpty ? nil : $0 }))
                    .padding(.top, 8)
            } label: {
                Text("revisão rápida").appFont(14, .medium).foregroundStyle(AppColors.secondaryText)
            }
            .tint(AppColors.secondaryText)
        }
    }

    private func transcribe() async {
        guard let file = note.audioFileName else { return }
        isTranscribing = true
        transcribeError = false
        defer { isTranscribing = false }
        do {
            let text = try await VoiceTranscriptionService.transcribe(fileName: file)
            note.rawText = text
            let embedded = EmbeddingService.shared.embed(note.embeddingInput)
            note.embedding = embedded.vector
            note.langCode = embedded.language
            HapticEngine.classify()
        } catch {
            transcribeError = true
        }
    }

    // MARK: - Calendar event card (Pro)

    private static let eventDateFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "EEE, MMM d · h:mm a"; return f
    }()
    private static let eventDayFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "EEE, MMM d"; return f
    }()

    private var eventCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("EVENT")
                .appFont(10.5, .medium, relativeTo: .caption2)
                .tracking(1.4)
                .foregroundStyle(AppColors.tertiaryText)
                .padding(.bottom, 12)

            HStack(spacing: 12) {
                Image(systemName: "calendar")
                    .appFont(16, .light, relativeTo: .body)
                    .foregroundStyle(AppColors.secondaryText)
                    .frame(width: 38, height: 38)
                    .background(AppColors.ink.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(note.eventTitle ?? "Event")
                        .appFont(15, .regular, relativeTo: .body)
                        .tracking(-0.1)
                        .foregroundStyle(AppColors.primaryText)
                        .lineLimit(1)
                    if let date = note.eventDate {
                        Text(note.eventHasTime
                             ? Self.eventDateFormatter.string(from: date)
                             : Self.eventDayFormatter.string(from: date))
                            .appFont(12.5, .light, relativeTo: .caption)
                            .foregroundStyle(AppColors.secondaryText)
                    }
                }

                Spacer()

                Button(action: addToCalendar) {
                    Group {
                        if addingEvent {
                            ProgressView().controlSize(.small)
                        } else {
                            Text("add")
                                .appFont(13, .medium, relativeTo: .subheadline)
                                .foregroundStyle(AppColors.onAccent)
                        }
                    }
                    .padding(.horizontal, 16)
                    .frame(height: 34)
                    .background(AppColors.ink)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(addingEvent)
            }
            .padding(12)
            .background(AppColors.ink.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(AppColors.ink.opacity(0.06), lineWidth: 0.5)
            )

            if let err = calError {
                Text(err)
                    .appFont(12, .light, relativeTo: .caption)
                    .foregroundStyle(AppColors.tertiaryText)
                    .padding(.top, 8)
                    .transition(.opacity)
            }
        }
    }

    private func addToCalendar() {
        guard !addingEvent else { return }
        if !appState.isPro { showCalProPrompt = true; return }
        guard let title = note.eventTitle, let date = note.eventDate else { return }

        addingEvent = true
        calError = nil
        let hasTime = note.eventHasTime
        let body = note.displayText ?? note.rawText
        Task {
            do {
                let id = try await CalendarService.shared.addEvent(
                    title: title, date: date, hasTime: hasTime, notes: body)
                await MainActor.run {
                    addingEvent = false
                    withAnimation(AppAnimation.springFluid) { note.calendarEventID = id }
                    HapticEngine.archive()
                }
            } catch {
                await MainActor.run {
                    addingEvent = false
                    withAnimation { calError = error.localizedDescription }
                    Task {
                        try? await Task.sleep(nanoseconds: 3_000_000_000)
                        await MainActor.run { withAnimation { calError = nil } }
                    }
                }
            }
        }
    }

    private var sheetContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            dragHandle

            // Fix 12: keyboard dismisses on scroll
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    headerRow.padding(.bottom, 8)
                    subtitleText.padding(.bottom, 10)
                    if note.isVoice {
                        voiceHero.padding(.bottom, 18)
                    }

                    noteTextArea.padding(.bottom, 18)

                    if note.hasMedia {
                        movieHero.padding(.bottom, 18)
                    }

                    if note.hasPendingEvent {
                        eventCard.padding(.bottom, 18)
                    }

                    if showEnhancer {
                        AIEnhancerInline(
                            note: note,
                            isPro: appState.isPro,
                            onKeep: { enhanced, mode in
                                note.displayText = enhanced
                                note.enhancementMode = mode.rawValue
                            },
                            onDismiss: {
                                withAnimation(AppAnimation.springFluid) { showEnhancer = false }
                            },
                            onEnhancingChanged: { enhancing in
                                isEnhancing = enhancing
                                withAnimation(enhancing
                                    ? AppAnimation.springGentle.repeatForever(autoreverses: true)
                                    : AppAnimation.springSnappy) {
                                    sparkPulse = enhancing
                                }
                            }
                        )
                        .padding(.bottom, 18)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    Divider().opacity(0.15).padding(.bottom, 16)

                    if note.type == .task && !note.tasks.isEmpty {
                        actionItemsSection
                        Divider().opacity(0.15).padding(.vertical, 16)
                    }

                    // Fix 7: increased section spacing
                    tagsSection.padding(.bottom, 20)

                    if !note.summary.isEmpty {
                        summarySection.padding(.bottom, 20)
                    }

                    revertSection.padding(.bottom, 22)

                    if allNotes.count >= 2 && !relatedNotes.isEmpty {
                        seeAlsoSection.padding(.bottom, 22)
                    }

                    // Fix 7: 28pt minimum before archive/delete row
                    bottomActions
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 34)
            }
            .scrollDismissesKeyboard(.immediately)
        }
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
        .frame(maxHeight: ((UIApplication.shared.connectedScenes.first as? UIWindowScene)?.screen.bounds.height ?? 852) * 0.88)
    }

    private var dragHandle: some View {
        HStack {
            Capsule()
                .fill(AppColors.ink.opacity(0.18))
                .frame(width: 36, height: 5)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 10)
        .padding(.bottom, 14)
        .contentShape(Rectangle())
        .gesture(
            DragGesture()
                .onChanged { value in
                    // Fix 8: 1:1 mapping, no animation while finger down
                    isDragging = true
                    sheetDragOffset = max(0, value.translation.height)
                }
                .onEnded { value in
                    isDragging = false
                    // Fix 8: velocity check using iOS 17 DragGesture.Value.velocity
                    let shouldDismiss = value.translation.height > 80 || value.velocity.height > 800
                    if shouldDismiss {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                            sheetDragOffset = 0
                        }
                        onClose()
                    } else {
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.9)) {
                            sheetDragOffset = 0
                        }
                    }
                }
        )
    }

    private var headerRow: some View {
        HStack {
            Button {
                showTypePicker = true
            } label: {
                NoteBadge(kind: note.type)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("type: \(note.type.rawValue), tap to change")

            Spacer()
            Text("captured · \(relativeTime)")
                .appFont(12, .light, relativeTo: .caption)
                .foregroundStyle(AppColors.tertiaryText)
                .accessibilityLabel("captured \(relativeTime)")
        }
    }

    private var subtitleText: some View {
        Text("from \(dayDescription).")
            .appFont(13, .light, relativeTo: .subheadline)
            .italic()
            .foregroundStyle(AppColors.tertiaryText)
    }

    private var noteTextArea: some View {
        let content = note.displayText ?? note.rawText
        let isLong = content.count > 120
        let textFont: Font = isLong
            ? .system(size: 15, weight: .light)
            : .system(size: 22, weight: .bold)
        let tracking: CGFloat = isLong ? -0.15 : -0.5
        let lineSpacing: CGFloat = isLong ? 7.5 : 4

        return ZStack(alignment: .topTrailing) {
            if isEditing {
                TextEditor(text: $editDraft)
                    .font(textFont)
                    .tracking(tracking)
                    .foregroundStyle(AppColors.primaryText)
                    .scrollContentBackground(.hidden)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(minHeight: 80)
                    .padding(.trailing, 72)
                    // Fix 12: Done button for TextEditor
                    .toolbar {
                        ToolbarItemGroup(placement: .keyboard) {
                            Spacer()
                            Button("Done") {
                                let trimmed = editDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                                if !trimmed.isEmpty {
                                    note.displayText = trimmed
                                    EmbeddingService.shared.reembed(note)
                                }
                                withAnimation(AppAnimation.springSnappy) { isEditing = false }
                            }
                        }
                    }
            } else {
                Text(content)
                    .font(textFont)
                    .tracking(tracking)
                    .lineSpacing(lineSpacing)
                    .foregroundStyle(AppColors.primaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.trailing, 72)
            }

            HStack(spacing: 8) {
                // Fix 3: darker bg, defined border, stronger glyph color
                Button {
                    if isEditing {
                        let trimmed = editDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmed.isEmpty {
                            note.displayText = trimmed
                            EmbeddingService.shared.reembed(note)
                        }
                        withAnimation(AppAnimation.springSnappy) { isEditing = false }
                    } else {
                        editDraft = note.displayText ?? note.rawText
                        withAnimation(AppAnimation.springSnappy) { isEditing = true }
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(AppColors.ink.opacity(0.10))
                            .frame(width: 28, height: 28)
                            .overlay(
                                Circle().stroke(AppColors.ink.opacity(0.12), lineWidth: 0.5)
                            )
                        Image(systemName: isEditing ? "checkmark" : "pencil")
                            .appFont(12, .medium, relativeTo: .caption)
                            .foregroundStyle(Color(hex: "3C3C3E"))
                    }
                }
                .buttonStyle(.plain)

                // Develop — open the focused full-screen editor for long-form
                Button { showDevelop = true } label: {
                    ZStack {
                        Circle()
                            .fill(AppColors.ink.opacity(0.10))
                            .frame(width: 28, height: 28)
                            .overlay(Circle().stroke(AppColors.ink.opacity(0.12), lineWidth: 0.5))
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .appFont(11, .medium, relativeTo: .caption2)
                            .foregroundStyle(Color(hex: "3C3C3E"))
                    }
                }
                .buttonStyle(.plain)

                Button {
                    withAnimation(AppAnimation.springFluid) { showEnhancer.toggle() }
                } label: {
                    ZStack {
                        Circle()
                            .fill(showEnhancer
                                  ? AnyShapeStyle(LinearGradient(colors: [AppColors.ctaTop, AppColors.ctaBottom], startPoint: .top, endPoint: .bottom))
                                  : AnyShapeStyle(AppColors.ink.opacity(0.10)))
                            .frame(width: 28, height: 28)
                            .overlay(
                                Circle().stroke(
                                    showEnhancer ? Color.clear : AppColors.ink.opacity(0.12),
                                    lineWidth: 0.5
                                )
                            )
                        Text("✦")
                            .appFont(12, .medium, relativeTo: .caption)
                            .foregroundStyle(showEnhancer ? AppColors.onAccent : Color(hex: "3C3C3E"))
                    }
                }
                .buttonStyle(.plain)
                .scaleEffect(sparkPulse ? 1.08 : 1.0)
                .animation(
                    isEnhancing
                        ? AppAnimation.springGentle.repeatForever(autoreverses: true)
                        : AppAnimation.springSnappy,
                    value: sparkPulse
                )
            }
            .offset(x: 4, y: -4)
        }
    }

    private var actionItemsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Fix 7: 14pt gap between section label and content
            Text("ACTION ITEMS")
                .appFont(10.5, .medium, relativeTo: .caption2)
                .tracking(1.4)
                .foregroundStyle(AppColors.tertiaryText)
                .padding(.bottom, 14)

            ForEach(Array(note.tasks.enumerated()), id: \.offset) { index, task in
                actionItem(index: index, text: task).frame(minHeight: 36)
            }

            dueDateRow
        }
    }

    private func actionItem(index: Int, text: String) -> some View {
        let checked = note.isTaskDone(index)
        return HStack(spacing: 12) {
            ZStack {
                if checked {
                    Circle().fill(AppColors.primaryText).frame(width: 18, height: 18)
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(AppColors.onAccent)
                } else {
                    Circle().stroke(AppColors.tertiaryText, lineWidth: 1.4).frame(width: 18, height: 18)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: checked)

            Text(text)
                .appFont(15, .light, relativeTo: .body)
                .tracking(-0.1)
                .foregroundStyle(checked ? AppColors.secondaryText : AppColors.primaryText)
                .strikethrough(checked, color: AppColors.secondaryText)
                .animation(.easeInOut(duration: 0.2), value: checked)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            // Persist completion on the note — survives closing the sheet.
            note.setTask(index, done: !checked)
            HapticEngine.classify()
        }
    }

    // MARK: - Due date

    @ViewBuilder
    private var dueDateRow: some View {
        let isOverdue = note.dueDate.map { $0 < Date() } ?? false
        HStack(spacing: 8) {
            Image(systemName: "calendar")
                .appFont(12, .light, relativeTo: .caption)
                .foregroundStyle(isOverdue ? AppColors.destructive : AppColors.tertiaryText)

            if note.dueDate == nil {
                Button {
                    note.dueDate = Calendar.current.date(byAdding: .day, value: 1, to: Date())
                } label: {
                    Text("add due date")
                        .appFont(13, .light, relativeTo: .subheadline)
                        .foregroundStyle(AppColors.secondaryText)
                }
                .buttonStyle(.plain)
            } else {
                DatePicker(
                    "",
                    selection: Binding(get: { note.dueDate ?? Date() }, set: { note.dueDate = $0 }),
                    displayedComponents: [.date, .hourAndMinute]
                )
                .labelsHidden()
                .appFont(13, .light, relativeTo: .subheadline)

                if isOverdue {
                    Text("overdue")
                        .appFont(11, .medium, relativeTo: .caption2)
                        .foregroundStyle(AppColors.destructive)
                }

                Spacer()

                Button { note.dueDate = nil } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(AppColors.tertiaryText)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 14)
    }

    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("TAGS")
                    .appFont(10.5, .medium, relativeTo: .caption2)
                    .tracking(1.4)
                    .foregroundStyle(AppColors.tertiaryText)

                Button {
                    withAnimation(AppAnimation.springFluid) { showAddTagField.toggle() }
                } label: {
                    Image(systemName: "plus")
                        .appFont(10, .medium, relativeTo: .caption2)
                        .foregroundStyle(AppColors.tertiaryText)
                        .frame(width: 18, height: 18)
                        .background(AppColors.ink.opacity(0.05))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            // Fix 7: 14pt gap between label and content
            .padding(.bottom, 14)

            if !note.tags.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(note.tags, id: \.self) { tag in
                        tagPill(tag)
                    }
                }
                .padding(.bottom, 10)
            }

            if showAddTagField {
                HStack(spacing: 6) {
                    TextField("new tag", text: $newTagText)
                        .appFont(12, .regular, relativeTo: .caption)
                        .tracking(-0.1)
                        .foregroundStyle(AppColors.primaryText)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .onSubmit { commitNewTag() }

                    Button(action: commitNewTag) {
                        Image(systemName: "return")
                            .appFont(11, .medium, relativeTo: .caption2)
                            .foregroundStyle(AppColors.secondaryText)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 10)
                .frame(height: 30)
                .background(Color.white.opacity(0.55))
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Color.white.opacity(0.6), lineWidth: 0.5))
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
        }
    }

    private func tagPill(_ tag: String) -> some View {
        HStack(spacing: 4) {
            Text(tag)
                .appFont(12, .regular, relativeTo: .caption)
                .tracking(-0.1)
                .foregroundStyle(AppColors.secondaryText)

            Button {
                withAnimation(AppAnimation.springFluid) {
                    note.tags.removeAll { $0 == tag }
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(AppColors.tertiaryText)
            }
            .buttonStyle(.plain)
        }
        .padding(.leading, 10)
        .padding(.trailing, 7)
        .frame(height: 26)
        .background(Color.white.opacity(0.55))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Color.white.opacity(0.6), lineWidth: 0.5))
    }

    private func commitNewTag() {
        let trimmed = newTagText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !note.tags.contains(trimmed) else {
            newTagText = ""
            return
        }
        withAnimation(AppAnimation.springFluid) {
            note.tags.append(trimmed)
            newTagText = ""
            showAddTagField = false
        }
    }

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Fix 7: 14pt gap between section label and content
            Text("SUMMARY")
                .appFont(10.5, .medium, relativeTo: .caption2)
                .tracking(1.4)
                .foregroundStyle(AppColors.tertiaryText)
                .padding(.bottom, 14)

            Text(note.summary)
                .appFont(15, .light, relativeTo: .body)
                .italic()
                .tracking(-0.1)
                .lineSpacing(6)
                .foregroundStyle(AppColors.secondaryText)
        }
    }

    // MARK: - Revert

    @ViewBuilder
    private var revertSection: some View {
        if let display = note.displayText, display != note.rawText {
            Button {
                showRevertConfirm = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.counterclockwise")
                        .appFont(12, .light, relativeTo: .caption)
                    Text("revert to original")
                        .appFont(13, .light, relativeTo: .subheadline)
                }
                .foregroundStyle(AppColors.secondaryText)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - See Also

    private var seeAlsoSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("SEE ALSO")
                .appFont(10.5, .medium, relativeTo: .caption2)
                .tracking(1.4)
                .foregroundStyle(AppColors.tertiaryText)

            VStack(spacing: 0) {
                ForEach(Array(relatedNotes.enumerated()), id: \.element.id) { i, related in
                    Button {
                        withAnimation(AppAnimation.springFluid) {
                            appState.activeNote = related
                        }
                    } label: {
                        HStack(spacing: 10) {
                            CatIcon(kind: related.type, size: 11, color: AppColors.tertiaryText)

                            Text(related.displayText ?? related.rawText)
                                .appFont(13, .light, relativeTo: .subheadline)
                                .tracking(-0.1)
                                .foregroundStyle(AppColors.primaryText)
                                .lineLimit(1)
                                .truncationMode(.tail)

                            Spacer()

                            Text(relativeTimeFor(related.createdAt))
                                .appFont(11, .light, relativeTo: .caption2)
                                .foregroundStyle(AppColors.tertiaryText)
                        }
                        .frame(minHeight: 44)
                    }
                    .buttonStyle(.plain)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                    .animation(AppAnimation.springSnappy.delay(Double(i) * 0.04), value: relatedNoteIDs)

                    if related.id != relatedNotes.last?.id {
                        Divider().opacity(0.1)
                    }
                }
            }
        }
    }

    // MARK: - Bottom actions

    private var bottomActions: some View {
        HStack {
            Button {
                if note.isArchived {
                    withAnimation(AppAnimation.springFluid) { note.isArchived = false }
                    onClose()
                } else {
                    onArchive()
                }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: note.isArchived ? "archivebox.fill" : "archivebox")
                        .appFont(12, .light, relativeTo: .caption)
                    Text(note.isArchived ? "unarchive" : "archive note")
                }
                .appFont(13, .light, relativeTo: .subheadline)
                .foregroundStyle(AppColors.secondaryText)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(note.isArchived ? "unarchive note" : "archive note")

            Spacer()

            Button { showDeleteAlert = true } label: {
                Text("delete note")
                    .appFont(13, .light, relativeTo: .subheadline)
                    .foregroundStyle(AppColors.destructive)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("delete note")
            .accessibilityHint("cannot be undone")
        }
        .padding(.top, 28)
    }

    // MARK: - Helpers

    private var relativeTime: String {
        let fmt = RelativeDateTimeFormatter()
        fmt.unitsStyle = .abbreviated
        return fmt.localizedString(for: note.createdAt, relativeTo: Date())
    }

    private func relativeTimeFor(_ date: Date) -> String {
        let fmt = RelativeDateTimeFormatter()
        fmt.unitsStyle = .abbreviated
        return fmt.localizedString(for: date, relativeTo: Date())
    }

    private var dayDescription: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        let hour = Calendar.current.component(.hour, from: note.createdAt)
        let timeOfDay: String
        switch hour {
        case 5..<12:  timeOfDay = "morning"
        case 12..<17: timeOfDay = "afternoon"
        case 17..<21: timeOfDay = "evening"
        default:      timeOfDay = "night"
        }
        return "a \(formatter.string(from: note.createdAt).lowercased()) \(timeOfDay)"
    }
}

// MARK: - FlowLayout

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 320
        var x: CGFloat = 0; var y: CGFloat = 0; var rowH: CGFloat = 0
        for sub in subviews {
            let sz = sub.sizeThatFits(.unspecified)
            if x + sz.width > width, x > 0 { x = 0; y += rowH + spacing; rowH = 0 }
            x += sz.width + spacing; rowH = max(rowH, sz.height)
        }
        return CGSize(width: width, height: y + rowH)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX; var y = bounds.minY; var rowH: CGFloat = 0
        for sub in subviews {
            let sz = sub.sizeThatFits(.unspecified)
            if x + sz.width > bounds.maxX, x > bounds.minX { x = bounds.minX; y += rowH + spacing; rowH = 0 }
            sub.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(sz))
            x += sz.width + spacing; rowH = max(rowH, sz.height)
        }
    }
}
