// LinkDetailPeek.swift — Center Peek sheet for library cards (long press)

import SwiftUI

struct LinkDetailPeek: View {
    let link: Link
    var onClose: () -> Void
    var onArchive: (Link) -> Void
    var onDelete: (Link) -> Void

    @Environment(\.openURL) private var openURL
    @State private var editingTitle = false
    @State private var titleDraft = ""
    @State private var showAddTagField = false
    @State private var newTagText = ""
    @State private var showDeleteAlert = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Thumbnail
                    LinkThumbnail(link: link)
                        .padding(.horizontal, 20)
                        .padding(.top, 4)
                        .padding(.bottom, 16)

                    Group {
                        titleSection
                        Divider().opacity(0.1).padding(.vertical, 14)
                        urlSection
                        Divider().opacity(0.1).padding(.vertical, 14)
                        tagsSection
                        Divider().opacity(0.1).padding(.vertical, 14)
                        noteSection
                        Divider().opacity(0.1).padding(.top, 14).padding(.bottom, 20)
                        actionsSection
                    }
                    .padding(.horizontal, 24)
                }
                .padding(.bottom, 40)
            }
            .background(Color(hex: "F4F6F8"))
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    PlatformPill(kind: link.kind)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("done", action: onClose)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(AppColors.primaryText)
                }
            }
        }
        .alert("Remove link?", isPresented: $showDeleteAlert) {
            Button("Remove", role: .destructive) { onDelete(link); onClose() }
            Button("Cancel", role: .cancel) {}
        } message: { Text("This cannot be undone.") }
    }

    // MARK: - Title

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("TITLE")
                .font(.system(size: 10.5, weight: .medium))
                .tracking(1.4)
                .foregroundStyle(AppColors.tertiaryText)

            if editingTitle {
                TextField("title", text: $titleDraft, axis: .vertical)
                    .font(.system(size: 17, weight: .semibold))
                    .tracking(-0.3)
                    .foregroundStyle(AppColors.primaryText)
                    .onSubmit { commitTitle() }
                    .toolbar {
                        ToolbarItemGroup(placement: .keyboard) {
                            Spacer()
                            Button("Done") { commitTitle() }
                        }
                    }
            } else {
                Text(link.title)
                    .font(.system(size: 17, weight: .semibold))
                    .tracking(-0.3)
                    .foregroundStyle(AppColors.primaryText)
                    .onTapGesture {
                        titleDraft = link.title
                        editingTitle = true
                    }
            }

            Text("tap to edit")
                .font(.system(size: 11, weight: .light))
                .foregroundStyle(AppColors.tertiaryText)
                .opacity(editingTitle ? 0 : 0.7)
        }
    }

    private func commitTitle() {
        let trimmed = titleDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { link.title = trimmed }
        editingTitle = false
    }

    // MARK: - URL

    private var urlSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("URL")
                .font(.system(size: 10.5, weight: .medium))
                .tracking(1.4)
                .foregroundStyle(AppColors.tertiaryText)

            Button {
                if let url = URL(string: link.urlString.hasPrefix("http") ? link.urlString : "https://\(link.urlString)") {
                    openURL(url)
                }
            } label: {
                Text(link.urlString)
                    .font(.system(size: 12, weight: .light))
                    .tracking(-0.1)
                    .foregroundStyle(AppColors.accentBlue)
                    .lineLimit(2)
                    .truncationMode(.middle)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Tags

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

            if !link.tags.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(link.tags, id: \.self) { tag in
                        tagPill(tag)
                    }
                }
            }

            if showAddTagField {
                HStack(spacing: 6) {
                    TextField("new tag", text: $newTagText)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(AppColors.primaryText)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .onSubmit { commitTag() }

                    Button(action: commitTag) {
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
                withAnimation(AppAnimation.springFluid) { link.tags.removeAll { $0 == tag } }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(AppColors.tertiaryText)
            }
            .buttonStyle(.plain)
        }
        .padding(.leading, 10).padding(.trailing, 7)
        .frame(height: 26)
        .background(Color.white.opacity(0.55))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Color.white.opacity(0.6), lineWidth: 0.5))
    }

    private func commitTag() {
        let t = newTagText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty, !link.tags.contains(t) else { newTagText = ""; return }
        withAnimation(AppAnimation.springFluid) {
            link.tags.append(t)
            newTagText = ""
            showAddTagField = false
        }
    }

    // MARK: - Note

    private var noteSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("MY NOTE")
                .font(.system(size: 10.5, weight: .medium))
                .tracking(1.4)
                .foregroundStyle(AppColors.tertiaryText)

            ZStack(alignment: .topLeading) {
                if link.userNote == nil || link.userNote!.isEmpty {
                    Text("add a note about this link…")
                        .font(.system(size: 14, weight: .light))
                        .foregroundStyle(AppColors.tertiaryText)
                        .padding(.top, 8).padding(.leading, 4)
                        .allowsHitTesting(false)
                }

                TextEditor(text: Binding(
                    get: { link.userNote ?? "" },
                    set: { link.userNote = $0.isEmpty ? nil : $0 }
                ))
                .font(.system(size: 14, weight: .light))
                .tracking(-0.1)
                .foregroundStyle(AppColors.primaryText)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 80)
            }
            .padding(10)
            .background(Color.white.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.6), lineWidth: 0.5))
        }
    }

    // MARK: - Actions

    private var actionsSection: some View {
        HStack {
            if !Link.samples.contains(where: { $0.id == link.id }) {
                Button {
                    onArchive(link)
                    onClose()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: link.isArchived ? "archivebox.fill" : "archivebox")
                            .font(.system(size: 12, weight: .light))
                        Text(link.isArchived ? "unarchive" : "archive")
                    }
                    .font(.system(size: 13, weight: .light))
                    .foregroundStyle(AppColors.secondaryText)
                }
                .buttonStyle(.plain)

                Spacer()

                Button { showDeleteAlert = true } label: {
                    Text("delete")
                        .font(.system(size: 13, weight: .light))
                        .foregroundStyle(AppColors.destructive)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - FlowLayout (local copy)

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
