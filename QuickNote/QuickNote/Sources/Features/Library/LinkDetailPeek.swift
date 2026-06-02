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
        // Fix 11: ZStack ensures drag indicator always renders above NavigationStack
        ZStack(alignment: .top) {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        // Fix 11: 28pt top padding gives drag indicator clear space
                        if link.kind != .article && link.kind != .bare {
                            PlatformPill(kind: link.kind)
                                .padding(.leading, 20)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.top, 28)
                                .padding(.bottom, 8)
                        }

                        // Thumbnail
                        LinkThumbnail(link: link)
                            .padding(.horizontal, 20)
                            .padding(.top, link.kind == .article || link.kind == .bare ? 28 : 4)
                            .padding(.bottom, 16)

                        Group {
                            titleSection
                            // Fix 7: 20pt between sections
                            Divider().opacity(0.1).padding(.vertical, 20)
                            if link.product != nil {
                                productSection
                                Divider().opacity(0.1).padding(.vertical, 20)
                            }
                            urlSection
                            Divider().opacity(0.1).padding(.vertical, 20)
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
                .scrollDismissesKeyboard(.immediately)
                .background(.ultraThinMaterial)
                .navigationTitle("")
                .navigationBarTitleDisplayMode(.inline)
            }

            // Fix 11: drag indicator on top with zIndex — never covered by image
            Capsule()
                .fill(AppColors.tertiaryText.opacity(0.45))
                .frame(width: 36, height: 4)
                .padding(.top, 8)
                .allowsHitTesting(false)
        }
        .alert("Delete this link?", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) { onDelete(link); onClose() }
            Button("Cancel", role: .cancel) {}
        } message: { Text("This cannot be undone.") }
    }

    // MARK: - Title

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("TITLE")
                .appFont(10.5, .medium, relativeTo: .caption2)
                .tracking(1.4)
                .foregroundStyle(AppColors.tertiaryText)
                .padding(.bottom, 6)

            if editingTitle {
                TextField("title", text: $titleDraft, axis: .vertical)
                    .appFont(17, .semibold, relativeTo: .headline)
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
                    .appFont(17, .semibold, relativeTo: .headline)
                    .tracking(-0.3)
                    .foregroundStyle(AppColors.primaryText)
                    .onTapGesture {
                        titleDraft = link.title
                        editingTitle = true
                    }
            }

            // Fix 7: 6pt gap between title and "tap to edit" hint
            Text("tap to edit")
                .appFont(11, .light, relativeTo: .caption2)
                .foregroundStyle(AppColors.tertiaryText)
                .opacity(editingTitle ? 0 : 0.7)
                .padding(.top, 6)
        }
    }

    private func commitTitle() {
        let trimmed = titleDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { link.title = trimmed }
        editingTitle = false
    }

    // MARK: - URL

    // MARK: - Product (enrichment)

    @ViewBuilder
    private var productSection: some View {
        if let product = link.product {
            VStack(alignment: .leading, spacing: 8) {
                Text("PRODUCT")
                    .appFont(10.5, .medium, relativeTo: .caption2)
                    .tracking(1.4)
                    .foregroundStyle(AppColors.tertiaryText)

                if let data = product.imageData, let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 160)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                Text(product.name)
                    .appFont(15, .semibold, relativeTo: .body)
                    .tracking(-0.2)
                    .foregroundStyle(AppColors.primaryText)

                HStack(spacing: 8) {
                    if let price = product.priceText {
                        Text(price)
                            .appFont(14, .semibold, relativeTo: .subheadline)
                            .foregroundStyle(AppColors.primaryText)
                    }
                    if let brand = product.brand {
                        Text(brand)
                            .appFont(12, .light, relativeTo: .caption)
                            .foregroundStyle(AppColors.secondaryText)
                    }
                    if let availability = product.availability {
                        Text("· \(availability)")
                            .appFont(12, .light, relativeTo: .caption)
                            .foregroundStyle(AppColors.secondaryText)
                    }
                }
            }
        }
    }

    private var urlSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("URL")
                .appFont(10.5, .medium, relativeTo: .caption2)
                .tracking(1.4)
                .foregroundStyle(AppColors.tertiaryText)

            Button {
                if let url = URL(string: link.urlString.hasPrefix("http") ? link.urlString : "https://\(link.urlString)") {
                    openURL(url)
                }
            } label: {
                Text(link.urlString)
                    .appFont(12, .light, relativeTo: .caption)
                    .tracking(-0.1)
                    .foregroundStyle(Color(hex: "6B7280"))
                    .underline()
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
                        .appFont(12, .regular, relativeTo: .caption)
                        .foregroundStyle(AppColors.primaryText)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .onSubmit { commitTag() }

                    Button(action: commitTag) {
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
                .appFont(10.5, .medium, relativeTo: .caption2)
                .tracking(1.4)
                .foregroundStyle(AppColors.tertiaryText)

            ZStack(alignment: .topLeading) {
                if link.userNote == nil || link.userNote!.isEmpty {
                    Text("add a note about this link…")
                        .appFont(14, .light, relativeTo: .subheadline)
                        .foregroundStyle(AppColors.tertiaryText)
                        .padding(.top, 8).padding(.leading, 4)
                        .allowsHitTesting(false)
                }

                TextEditor(text: Binding(
                    get: { link.userNote ?? "" },
                    set: { link.userNote = $0.isEmpty ? nil : $0 }
                ))
                .appFont(14, .light, relativeTo: .subheadline)
                .tracking(-0.1)
                .foregroundStyle(AppColors.primaryText)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 80)
                // Fix 12: Done button for note TextEditor
                .toolbar {
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button("Done") {
                            UIApplication.shared.sendAction(
                                #selector(UIResponder.resignFirstResponder),
                                to: nil, from: nil, for: nil
                            )
                        }
                    }
                }
            }
            .padding(10)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.white.opacity(0.5), lineWidth: 0.5))
        }
    }

    // MARK: - Actions

    private var actionsSection: some View {
        HStack {
            Button {
                onArchive(link)
                onClose()
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: link.isArchived ? "archivebox.fill" : "archivebox")
                        .appFont(12, .light, relativeTo: .caption)
                    Text(link.isArchived ? "unarchive" : "archive")
                }
                .appFont(13, .light, relativeTo: .subheadline)
                .foregroundStyle(AppColors.secondaryText)
            }
            .buttonStyle(.plain)

            Spacer()

            Button { showDeleteAlert = true } label: {
                Text("delete")
                    .appFont(13, .light, relativeTo: .subheadline)
                    .foregroundStyle(AppColors.destructive)
            }
            .buttonStyle(.plain)
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
