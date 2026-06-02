// LibraryView.swift — the quieter shelf (URL collection, 2-column masonry)

import SwiftUI
import SwiftData

struct LibraryView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL
    @Query(sort: \Link.createdAt, order: .reverse) private var savedLinks: [Link]
    @Query(filter: #Predicate<Note> { !$0.isArchived }) private var activeNotes: [Note]

    @Environment(\.scenePhase) private var scenePhase

    @State private var showAddLink = false
    @State private var pendingURL = ""
    @State private var peekLink: Link? = nil
    // Fix 6: sort sheet state
    @State private var showSortSheet = false

    private var displayedLinks: [Link] {
        if appState.libraryFilter == .archived {
            return savedLinks.filter { $0.isArchived }
        }
        var base = savedLinks.filter { !$0.isArchived }
        if appState.libraryFilter != .all {
            base = base.filter { appState.libraryFilter.matches($0.kind) }
        }
        if appState.libraryDateFilter != .none {
            base = base.filter {
                appState.libraryDateFilter.matches($0.createdAt,
                    customStart: appState.libraryCustomStart,
                    customEnd: appState.libraryCustomEnd)
            }
        }
        if let tag = appState.libraryTagFilter {
            base = base.filter { $0.tags.contains(tag) }
        }
        switch appState.librarySortOrder {
        case .newest: return base
        case .oldest: return base.reversed()
        case .byType: return base.sorted { $0.kind.rawValue < $1.kind.rawValue }
        }
    }

    private var availableTags: [String] {
        Array(Set(savedLinks.filter { !$0.isArchived }.flatMap { $0.tags })).sorted()
    }

    private var totalLinkCount: Int {
        savedLinks.filter { !$0.isArchived }.count
    }

    var body: some View {
        ZStack {
            WallpaperView()

            VStack(spacing: 0) {
                navRow
                titleBlock
                // Fix 6: sort button to the right of filter chips
                HStack(alignment: .center, spacing: 0) {
                    filterRow
                    librarySortButton
                }
                secondaryFilterRow
                // Fix 10: 0.5pt divider replaces gradient fade
                AppColors.hairline
                    .frame(height: 0.5)
                    .frame(maxWidth: .infinity)
                linkGrid
            }

            if showAddLink {
                addLinkPanel
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(AppAnimation.springFluid, value: showAddLink)
        .transition(.move(edge: .trailing))
        .sheet(item: $peekLink) { link in
            LinkDetailPeek(
                link: link,
                onClose: { peekLink = nil },
                onArchive: { archiveLink($0) },
                onDelete: { deleteLink($0) }
            )
            .presentationDetents([.large])
            .presentationBackground(.ultraThinMaterial)
            .presentationDragIndicator(.hidden)
        }
    }

    // MARK: - Nav

    private var navRow: some View {
        HStack {
            // Fix 5: badge anchored to top-right of pill via overlay
            Button {
                withAnimation(AppAnimation.springFluid) { appState.stage = .inbox }
            } label: {
                HStack(spacing: 8) {
                    MarkGlyph(size: 14, strokeWidth: 1.4)
                    Text("mind")
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
                    Text("\(activeNotes.count)")
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

            Spacer()

            Button {
                pendingURL = UIPasteboard.general.string?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                if !isValidURL(pendingURL) { pendingURL = "" }
                withAnimation(AppAnimation.springFluid) { showAddLink = true }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "plus")
                        .appFont(11, .semibold, relativeTo: .caption2)
                    Text("add link")
                        .appFont(13, .regular, relativeTo: .subheadline)
                        .tracking(-0.1)
                }
                .foregroundStyle(AppColors.primaryText)
                .padding(.leading, 10)
                .padding(.trailing, 12)
                .frame(height: 32)
                .background(AppColors.ink.opacity(0.06))
                .clipShape(Capsule())
                .overlay(Capsule().stroke(AppColors.ink.opacity(0.04), lineWidth: 0.5))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .frame(height: 44)
    }

    // MARK: - Title

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("quieter shelf.")
                .appFont(12, .light, relativeTo: .caption)
                .tracking(-0.05)
                .foregroundStyle(AppColors.tertiaryText)

            HStack(alignment: .firstTextBaseline) {
                Text("library")
                    .appFont(34, .heavy, relativeTo: .largeTitle)
                    .tracking(-1)
                    .foregroundStyle(AppColors.primaryText)

                Text(" · \(totalLinkCount) saved")
                    .appFont(12, .light, relativeTo: .caption)
                    .tracking(-0.1)
                    .foregroundStyle(AppColors.tertiaryText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 4)
        .padding(.bottom, 16)
    }

    // MARK: - Filter chips

    private var filterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(LibraryFilterType.allCases, id: \.self) { type in
                    libraryChip(for: type)
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.bottom, 14)
    }

    private func libraryChip(for type: LibraryFilterType) -> some View {
        let isActive = appState.libraryFilter == type
        return Button {
            withAnimation(AppAnimation.springSnappy) { appState.libraryFilter = type }
        } label: {
            Pill(isActive: isActive) {
                Text(type.label)
                    .appFont(10.5, .medium, relativeTo: .caption2)
                    .tracking(0.3)
                    .textCase(.uppercase)
                    .foregroundStyle(isActive ? AppColors.onAccent : AppColors.secondaryText)
            }
        }
        .buttonStyle(PressStyle())
        .accessibilityLabel(type.label)
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }

    // MARK: - Sort button (Fix 6)

    private var librarySortButton: some View {
        Button {
            showSortSheet = true
        } label: {
            Image(systemName: "line.3.horizontal.decrease")
                .appFont(13, .regular, relativeTo: .subheadline)
                .foregroundStyle(appState.librarySortOrder == .newest
                                 ? AppColors.secondaryText
                                 : AppColors.primaryText)
                .frame(width: 36, height: 36)
                .background(appState.librarySortOrder == .newest
                             ? AppColors.ink.opacity(0.04)
                             : AppColors.ink.opacity(0.10))
                .clipShape(Circle())
                .overlay(Circle().stroke(AppColors.ink.opacity(0.06), lineWidth: 0.5))
        }
        .buttonStyle(.plain)
        .padding(.trailing, 12)
        .padding(.bottom, 14)
        .confirmationDialog("Sort by", isPresented: $showSortSheet, titleVisibility: .visible) {
            Button("Newest First") {
                withAnimation(AppAnimation.springSnappy) { appState.librarySortOrder = .newest }
            }
            Button("Oldest First") {
                withAnimation(AppAnimation.springSnappy) { appState.librarySortOrder = .oldest }
            }
            Button("Type") {
                withAnimation(AppAnimation.springSnappy) { appState.librarySortOrder = .byType }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: - Tag-only secondary filter row (Fix 6: DATE removed)

    @ViewBuilder
    private var secondaryFilterRow: some View {
        let hasActiveTagFilter = appState.libraryTagFilter != nil
        if !availableTags.isEmpty || hasActiveTagFilter {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(availableTags, id: \.self) { tag in
                        tagChip(tag, isActive: appState.libraryTagFilter == tag) {
                            withAnimation(AppAnimation.springSnappy) {
                                appState.libraryTagFilter = appState.libraryTagFilter == tag ? nil : tag
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
            .padding(.vertical, 8)
        }
    }

    private func tagChip(_ label: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text("#\(label)")
                .appFont(10.5, .medium, relativeTo: .caption2)
                .tracking(0.2)
                .foregroundStyle(isActive ? AppColors.onAccent : AppColors.secondaryText)
                .padding(.horizontal, 10)
                .frame(height: 24)
                .background(
                    isActive
                        ? AnyShapeStyle(LinearGradient(colors: [AppColors.ctaTop, AppColors.ctaBottom], startPoint: .top, endPoint: .bottom))
                        : AnyShapeStyle(AppColors.ink.opacity(0.04))
                )
                .clipShape(Capsule())
                .overlay(Capsule().stroke(AppColors.ink.opacity(isActive ? 0 : 0.06), lineWidth: 0.5))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Masonry grid

    private var linkGrid: some View {
        Group {
            if displayedLinks.isEmpty {
                emptyLibrary
            } else {
                ScrollView {
                    MasonryColumns(
                        links: displayedLinks,
                        onOpen: openLink,
                        onArchive: archiveLink,
                        onDelete: deleteLink,
                        onPeek: { link in peekLink = link }
                    )
                    .padding(.horizontal, 16)
                    .padding(.bottom, 40)
                }
                .scrollDismissesKeyboard(.immediately)
            }
        }
        .task {
            drainPendingLinks()
            await fetchMissingMetadata()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { drainPendingLinks() }
        }
    }

    private var emptyLibrary: some View {
        VStack(spacing: 8) {
            Spacer()
            Text("nothing saved yet.")
                .appFont(15, .light, relativeTo: .body)
                .tracking(-0.1)
                .foregroundStyle(AppColors.tertiaryText)
            Text("paste a URL in the capture bar to save a link.")
                .appFont(12, .light, relativeTo: .caption)
                .tracking(-0.05)
                .foregroundStyle(AppColors.tertiaryText.opacity(0.7))
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding(.horizontal, 40)
    }

    // MARK: - Add link panel

    private var addLinkPanel: some View {
        ZStack(alignment: .bottom) {
            AppColors.ink.opacity(0.18)
                .ignoresSafeArea()
                .background(.ultraThinMaterial.opacity(0.3))
                .onTapGesture {
                    withAnimation(AppAnimation.springFluid) { showAddLink = false }
                }

            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Capsule()
                        .fill(AppColors.ink.opacity(0.18))
                        .frame(width: 36, height: 5)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 10)
                .padding(.bottom, 20)

                Text("add link")
                    .appFont(22, .bold, relativeTo: .title2)
                    .tracking(-0.5)
                    .foregroundStyle(AppColors.primaryText)
                    .padding(.bottom, 20)

                HStack(spacing: 10) {
                    TextField("paste or type a URL", text: $pendingURL)
                        .appFont(14, .regular, relativeTo: .subheadline)
                        .foregroundStyle(AppColors.primaryText)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        .onSubmit { commitLink() }

                    if !pendingURL.isEmpty {
                        Button {
                            pendingURL = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 15))
                                .foregroundStyle(AppColors.tertiaryText)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 14)
                .frame(height: 44)
                .background(Color.white.opacity(0.6))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.7), lineWidth: 0.5)
                )
                .padding(.bottom, 14)
                // Fix 12: Done button for URL field keyboard
                .toolbar {
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button("Done") { commitLink() }
                    }
                }

                HStack(spacing: 10) {
                    Button {
                        withAnimation(AppAnimation.springFluid) { showAddLink = false }
                    } label: {
                        Text("cancel")
                            .appFont(15, .regular, relativeTo: .body)
                            .foregroundStyle(AppColors.secondaryText)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(AppColors.ink.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 13))
                    }
                    .buttonStyle(.plain)

                    Button(action: commitLink) {
                        Text("save")
                            .appFont(15, .semibold, relativeTo: .body)
                            .foregroundStyle(AppColors.onAccent)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(
                                LinearGradient(colors: [AppColors.ctaTop, AppColors.ctaBottom],
                                               startPoint: .top, endPoint: .bottom)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 13))
                    }
                    .buttonStyle(.plain)
                    .disabled(!isValidURL(pendingURL))
                    .opacity(isValidURL(pendingURL) ? 1 : 0.4)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
            .background(Color(hex: "F4F6F8"))
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(Color.white.opacity(0.6), lineWidth: 0.5)
                    .padding(.bottom, -28)
            )
        }
        .ignoresSafeArea()
    }

    // MARK: - Actions

    private func commitLink() {
        let trimmed = pendingURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isValidURL(trimmed) else { return }
        saveLink(trimmed)
        withAnimation(AppAnimation.springFluid) {
            pendingURL = ""
            showAddLink = false
        }
    }

    private func openLink(_ link: Link) {
        guard let url = URL(string: link.urlString.hasPrefix("http") ? link.urlString : "https://\(link.urlString)") else { return }
        openURL(url)
    }

    private func isValidURL(_ string: String) -> Bool {
        guard !string.isEmpty,
              let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else { return false }
        let range = NSRange(string.startIndex..., in: string)
        return detector.firstMatch(in: string, range: range) != nil
    }

    private func archiveLink(_ link: Link) {
        withAnimation(AppAnimation.springFluid) { link.isArchived = true }
    }

    private func deleteLink(_ link: Link) {
        withAnimation(AppAnimation.springFluid) { modelContext.delete(link) }
    }

    private func drainPendingLinks() {
        let groupID = "group.com.prototype.QuickNote"
        guard let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupID) else { return }
        let fileURL = container.appendingPathComponent("pendingLinks.json")
        guard let data = try? Data(contentsOf: fileURL),
              let items = try? JSONDecoder().decode([[String: String]].self, from: data) else { return }
        try? FileManager.default.removeItem(at: fileURL)
        for item in items {
            guard let content = item["content"], !content.isEmpty else { continue }
            saveLink(content)
        }
    }

    private func saveLink(_ urlString: String) {
        let host = extractHost(from: urlString)
        let kind = LinkKind.detect(from: urlString)
        let link = Link(urlString: urlString, title: host, host: host, kind: kind)
        modelContext.insert(link)
        fetchAndApplyMetadata(link)
    }

    private func fetchAndApplyMetadata(_ link: Link) {
        let urlString = link.urlString
        let kind = link.kind
        Task {
            let meta = await LinkMetadataService.shared.fetch(urlString: urlString, kind: kind)
            // Download bytes off the main actor so the preview survives URL expiry.
            var imageData: Data? = nil
            if let thumb = meta.thumbnailURLString {
                imageData = await LinkMetadataService.shared.imageData(from: thumb)
            }
            await MainActor.run {
                if let title = meta.title, !title.isEmpty { link.title = title }
                if let thumb = meta.thumbnailURLString { link.thumbnailURL = thumb }
                if let imageData { link.thumbnailData = imageData }
                if let author = meta.author { link.author = author }
                if var product = meta.product {
                    product.imageData = imageData ?? link.thumbnailData
                    link.product = product
                    link.kind = .product
                }
            }
        }
    }

    private func fetchMissingMetadata() async {
        for link in savedLinks where link.thumbnailData == nil {
            fetchAndApplyMetadata(link)
        }
    }

    private func extractHost(from url: String) -> String {
        guard let parsed = URL(string: url.hasPrefix("http") ? url : "https://\(url)"),
              let host = parsed.host else { return url }
        return host.replacingOccurrences(of: "www.", with: "")
    }
}

// MARK: - Two-column masonry

private struct MasonryColumns: View {
    let links: [Link]
    var onOpen: (Link) -> Void
    var onArchive: (Link) -> Void
    var onDelete: (Link) -> Void
    var onPeek: (Link) -> Void

    private var leftColumn:  [Link] { links.enumerated().filter { $0.offset % 2 == 0 }.map(\.element) }
    private var rightColumn: [Link] { links.enumerated().filter { $0.offset % 2 != 0 }.map(\.element) }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            column(links: leftColumn,  delay: 0)
            column(links: rightColumn, delay: 40)
        }
    }

    private func column(links: [Link], delay: Int) -> some View {
        LazyVStack(spacing: 14) {
            ForEach(Array(links.enumerated()), id: \.element.id) { i, link in
                SwipeableLinkCard(link: link, onOpen: onOpen, onArchive: onArchive, onDelete: onDelete, onPeek: onPeek)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                    .animation(
                        AppAnimation.springFluid.delay(Double(delay + i * 60) / 1000),
                        value: links.count
                    )
            }
        }
    }
}

// MARK: - SwipeableLinkCard

private struct SwipeableLinkCard: View {
    let link: Link
    var onOpen: (Link) -> Void
    var onArchive: (Link) -> Void
    var onDelete: (Link) -> Void
    var onPeek: (Link) -> Void

    @State private var dragOffset: CGFloat = 0
    @State private var showDeleteAlert = false
    // Fix 1: proper gesture anchor tracking
    @State private var isDragging = false
    @State private var dragAnchorOffset: CGFloat = 0

    private let actionWidth: CGFloat = 60
    private let revealThreshold: CGFloat = 44

    var body: some View {
        ZStack {
            // Fix 1: right swipe → archive (left side)
            if dragOffset > 4 {
                HStack {
                    Button {
                        withAnimation(AppAnimation.springFluid) { dragOffset = 0 }
                        onArchive(link)
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: "archivebox")
                                .appFont(13, .light, relativeTo: .subheadline)
                            Text("ARCHIVE")
                                .appFont(9, .medium, relativeTo: .caption2)
                                .tracking(0.3)
                        }
                        .foregroundStyle(AppColors.secondaryText)
                        .frame(width: actionWidth)
                        .frame(maxHeight: .infinity)
                        .background(AppColors.ink.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }
            }

            // Fix 1: left swipe → delete (right side)
            if dragOffset < -4 {
                HStack {
                    Spacer()
                    Button { showDeleteAlert = true } label: {
                        VStack(spacing: 4) {
                            Image(systemName: "trash")
                                .appFont(13, .light, relativeTo: .subheadline)
                            Text("DELETE")
                                .appFont(9, .medium, relativeTo: .caption2)
                                .tracking(0.3)
                        }
                        .foregroundStyle(.white)
                        .frame(width: actionWidth)
                        .frame(maxHeight: .infinity)
                        .background(AppColors.destructive)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                }
            }

            LinkCard(link: link)
                .pressable(scale: 0.985)
                .offset(x: dragOffset)
                .simultaneousGesture(swipeGesture)
                .simultaneousGesture(
                    TapGesture().onEnded {
                        if dragOffset != 0 {
                            withAnimation(AppAnimation.springSnappy) { dragOffset = 0 }
                        } else {
                            onOpen(link)
                        }
                    }
                )
                .simultaneousGesture(
                    LongPressGesture(minimumDuration: 0.5)
                        .onEnded { _ in
                            guard dragOffset == 0 else { return }
                            onPeek(link)
                        }
                )
        }
        // Fix 1: updated alert text
        .alert("Delete this link?", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) {
                withAnimation(AppAnimation.springFluid) { dragOffset = 0 }
                onDelete(link)
            }
            Button("Cancel", role: .cancel) {
                withAnimation(AppAnimation.springSnappy) { dragOffset = 0 }
            }
        } message: {
            Text("This cannot be undone.")
        }
    }

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 20, coordinateSpace: .local)
            .onChanged { value in
                let h = abs(value.translation.width)
                let v = abs(value.translation.height)
                guard h > v * 2.0 else { return }
                if !isDragging {
                    isDragging = true
                    dragAnchorOffset = dragOffset
                }
                let newOffset = dragAnchorOffset + value.translation.width
                dragOffset = max(-actionWidth, min(actionWidth, newOffset))
            }
            .onEnded { value in
                isDragging = false
                let h = abs(value.translation.width)
                let v = abs(value.translation.height)
                guard h > v * 1.5 else {
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
                    }
                }
            }
    }
}
