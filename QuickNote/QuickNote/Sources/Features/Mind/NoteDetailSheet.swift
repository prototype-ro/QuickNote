// NoteDetailSheet.swift — bottom sheet for full note view

import SwiftUI
import SwiftData

struct NoteDetailSheet: View {
    let note: Note
    var onClose: () -> Void
    var onArchive: () -> Void
    var onDelete: () -> Void

    @Environment(AppState.self) private var appState
    @Query(filter: #Predicate<Note> { !$0.isArchived }) private var allNotes: [Note]

    @State private var checkedItems: Set<Int> = []
    @State private var showDeleteAlert = false
    @State private var showEnhancer = false
    @State private var showTypePicker = false
    @State private var showAddTagField = false
    @State private var newTagText = ""
    @State private var relatedNoteIDs: [UUID] = []
    @State private var processor = NoteProcessor()

    private var relatedNotes: [Note] {
        relatedNoteIDs.compactMap { id in allNotes.first { $0.id == id } }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color(hex: "0A0A0B").opacity(0.18)
                .ignoresSafeArea()
                .background(.ultraThinMaterial.opacity(0.3))
                .onTapGesture(perform: onClose)

            sheetContent
                .transition(.move(edge: .bottom))
        }
        .ignoresSafeArea()
        .alert("Delete note?", isPresented: $showDeleteAlert) {
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
            relatedNoteIDs = await processor.findRelatedNoteIDs(for: note, from: allNotes)
        }
    }

    private var sheetContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            dragHandle

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    headerRow.padding(.bottom, 8)
                    subtitleText.padding(.bottom, 10)
                    noteTextArea.padding(.bottom, 18)

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

                    tagsSection.padding(.bottom, 18)

                    if !note.summary.isEmpty {
                        summarySection.padding(.bottom, 22)
                    }

                    if !relatedNotes.isEmpty {
                        seeAlsoSection.padding(.bottom, 22)
                    }

                    bottomActions
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 34)
            }
        }
        .background(Color(hex: "F4F6F8"))
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.6), lineWidth: 0.5)
                .padding(.bottom, -28)
        )
        .frame(maxHeight: UIScreen.main.bounds.height * 0.88)
    }

    private var dragHandle: some View {
        HStack {
            Capsule()
                .fill(Color(hex: "0A0A0B").opacity(0.18))
                .frame(width: 36, height: 5)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 10)
        .padding(.bottom, 14)
    }

    private var headerRow: some View {
        HStack {
            Button {
                showTypePicker = true
            } label: {
                NoteBadge(kind: note.type)
            }
            .buttonStyle(.plain)

            Spacer()
            Text("captured · \(relativeTime)")
                .font(.system(size: 12, weight: .light))
                .foregroundStyle(AppColors.tertiaryText)
        }
    }

    private var subtitleText: some View {
        Text("from \(dayDescription).")
            .font(.system(size: 13, weight: .light))
            .italic()
            .foregroundStyle(AppColors.tertiaryText)
    }

    private var noteTextArea: some View {
        ZStack(alignment: .topTrailing) {
            Text(note.displayText ?? note.rawText)
                .font(.system(size: 22, weight: .bold))
                .tracking(-0.5)
                .lineSpacing(4)
                .foregroundStyle(AppColors.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                withAnimation(AppAnimation.springFluid) { showEnhancer.toggle() }
            } label: {
                ZStack {
                    Circle()
                        .fill(showEnhancer
                              ? AnyShapeStyle(LinearGradient(colors: [Color(hex: "1a1a1d"), .black], startPoint: .top, endPoint: .bottom))
                              : AnyShapeStyle(Color(hex: "0A0A0B").opacity(0.06)))
                        .frame(width: 28, height: 28)
                    Text("✦")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(showEnhancer ? Color.white : AppColors.secondaryText)
                }
            }
            .buttonStyle(.plain)
            .offset(x: 4, y: -4)
        }
    }

    private var actionItemsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("ACTION ITEMS")
                .font(.system(size: 10.5, weight: .medium))
                .tracking(1.4)
                .foregroundStyle(AppColors.tertiaryText)
                .padding(.bottom, 10)

            ForEach(Array(note.tasks.enumerated()), id: \.offset) { index, task in
                actionItem(index: index, text: task).frame(minHeight: 36)
            }
        }
    }

    private func actionItem(index: Int, text: String) -> some View {
        let checked = checkedItems.contains(index)
        return HStack(spacing: 12) {
            ZStack {
                if checked {
                    Circle().fill(AppColors.primaryText).frame(width: 18, height: 18)
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                } else {
                    Circle().stroke(AppColors.tertiaryText, lineWidth: 1.4).frame(width: 18, height: 18)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: checked)

            Text(text)
                .font(.system(size: 15, weight: .light))
                .tracking(-0.1)
                .foregroundStyle(checked ? AppColors.secondaryText : AppColors.primaryText)
                .strikethrough(checked, color: AppColors.secondaryText)
                .animation(.easeInOut(duration: 0.2), value: checked)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if checked { checkedItems.remove(index) } else { checkedItems.insert(index) }
        }
    }

    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("TAGS")
                    .font(.system(size: 10.5, weight: .medium))
                    .tracking(1.4)
                    .foregroundStyle(AppColors.tertiaryText)

                Button {
                    withAnimation(AppAnimation.springFluid) { showAddTagField.toggle() }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(AppColors.tertiaryText)
                        .frame(width: 18, height: 18)
                        .background(Color(hex: "0A0A0B").opacity(0.05))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }

            if !note.tags.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(note.tags, id: \.self) { tag in
                        tagPill(tag)
                    }
                }
            }

            if showAddTagField {
                HStack(spacing: 6) {
                    TextField("new tag", text: $newTagText)
                        .font(.system(size: 12, weight: .regular))
                        .tracking(-0.1)
                        .foregroundStyle(AppColors.primaryText)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .onSubmit { commitNewTag() }

                    Button(action: commitNewTag) {
                        Image(systemName: "return")
                            .font(.system(size: 11, weight: .medium))
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
                .font(.system(size: 12, weight: .regular))
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
        VStack(alignment: .leading, spacing: 8) {
            Text("SUMMARY")
                .font(.system(size: 10.5, weight: .medium))
                .tracking(1.4)
                .foregroundStyle(AppColors.tertiaryText)

            Text(note.summary)
                .font(.system(size: 15, weight: .light))
                .italic()
                .tracking(-0.1)
                .lineSpacing(6)
                .foregroundStyle(AppColors.secondaryText)
        }
    }

    // MARK: - See Also

    private var seeAlsoSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("SEE ALSO")
                .font(.system(size: 10.5, weight: .medium))
                .tracking(1.4)
                .foregroundStyle(AppColors.tertiaryText)

            VStack(spacing: 0) {
                ForEach(relatedNotes) { related in
                    Button {
                        withAnimation(AppAnimation.springFluid) {
                            appState.activeNote = related
                        }
                    } label: {
                        HStack(spacing: 10) {
                            CatIcon(kind: related.type, size: 11, color: AppColors.tertiaryText)

                            Text(related.rawText)
                                .font(.system(size: 13, weight: .light))
                                .tracking(-0.1)
                                .foregroundStyle(AppColors.primaryText)
                                .lineLimit(1)
                                .truncationMode(.tail)

                            Spacer()

                            Text(relativeTimeFor(related.createdAt))
                                .font(.system(size: 11, weight: .light))
                                .foregroundStyle(AppColors.tertiaryText)
                        }
                        .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)

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
                        .font(.system(size: 12, weight: .light))
                    Text(note.isArchived ? "unarchive" : "archive note")
                }
                .font(.system(size: 13, weight: .light))
                .foregroundStyle(AppColors.secondaryText)
            }
            .buttonStyle(.plain)

            Spacer()

            Button { showDeleteAlert = true } label: {
                Text("delete note")
                    .font(.system(size: 13, weight: .light))
                    .foregroundStyle(AppColors.destructive)
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 4)
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
        return "a \(formatter.string(from: note.createdAt).lowercased()) afternoon"
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
