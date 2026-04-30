// LibraryView.swift — the quieter shelf (URL collection, 2-column masonry)

import SwiftUI
import SwiftData

struct LibraryView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL
    @Query(sort: \Link.createdAt, order: .reverse) private var savedLinks: [Link]
    @Query(filter: #Predicate<Note> { !$0.isArchived }) private var activeNotes: [Note]

    @State private var showAddLink = false
    @State private var pendingURL = ""
    @State private var peekLink: Link? = nil
    @State private var showDateFilter = false

    private var displayedLinks: [Link] {
        if appState.libraryFilter == .archived {
            return savedLinks.filter { $0.isArchived }
        }
        var base = savedLinks.isEmpty ? Link.samples : savedLinks.filter { !$0.isArchived }
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
        return base
    }

    private var availableTags: [String] {
        let base = savedLinks.isEmpty ? Link.samples : savedLinks.filter { !$0.isArchived }
        return Array(Set(base.flatMap { $0.tags })).sorted()
    }

    private var totalLinkCount: Int {
        savedLinks.isEmpty ? Link.samples.count : savedLinks.filter { !$0.isArchived }.count
    }

    var body: some View {
        ZStack {
            WallpaperView()

            VStack(spacing: 0) {
                navRow
                titleBlock
                filterRow
                secondaryFilterRow
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
            .presentationBackground(Color(hex: "F4F6F8"))
            .presentationDragIndicator(.hidden)
        }
    }

    // MARK: - Nav

    private var navRow: some View {
        HStack {
            Button {
                withAnimation(AppAnimation.springFluid) { appState.stage = .inbox }
            } label: {
                HStack(spacing: 8) {
                    MarkGlyph(size: 14, strokeWidth: 1.4)
                    Text("mind")
                        .font(.system(size: 13, weight: .regular))
                        .tracking(-0.1)
                        .foregroundStyle(AppColors.primaryText)
                    Text("\(activeNotes.count)")
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

            Spacer()

            Button {
                pendingURL = UIPasteboard.general.string?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                if !isValidURL(pendingURL) { pendingURL = "" }
                withAnimation(AppAnimation.springFluid) { showAddLink = true }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .semibold))
                    Text("add link")
                        .font(.system(size: 13, weight: .regular))
                        .tracking(-0.1)
                }
                .foregroundStyle(AppColors.primaryText)
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

    // MARK: - Title

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("quieter shelf.")
                .font(.system(size: 12, weight: .light))
                .tracking(-0.05)
                .foregroundStyle(AppColors.tertiaryText)

            HStack(alignment: .firstTextBaseline) {
                Text("library")
                    .font(.system(size: 34, weight: .heavy))
                    .tracking(-1)
                    .foregroundStyle(AppColors.primaryText)

                Text(" · \(totalLinkCount) saved")
                    .font(.system(size: 12, weight: .light))
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
            Text(type.label)
                .font(.system(size: 10.5, weight: .medium))
                .tracking(0.3)
                .textCase(.uppercase)
                .foregroundStyle(isActive ? .white : AppColors.secondaryText)
                .padding(.horizontal, 10)
                .frame(height: 26)
                .background(
                    isActive
                        ? AnyShapeStyle(LinearGradient(colors: [Color(hex: "1a1a1d"), .black],
                                                       startPoint: .top, endPoint: .bottom))
                        : AnyShapeStyle(Color(hex: "0A0A0B").opacity(0.06))
                )
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Color(hex: "0A0A0B").opacity(isActive ? 0 : 0.04), lineWidth: 0.5))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Date + Tag secondary filter row

    @ViewBuilder
    private var secondaryFilterRow: some View {
        let hasTags = !availableTags.isEmpty
        let hasActiveFilters = appState.libraryDateFilter != .none || appState.libraryTagFilter != nil
        if hasTags || hasActiveFilters {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    libraryDateFilterChip
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
            .padding(.bottom, 10)
        }
    }

    private var libraryDateFilterChip: some View {
        let isActive = appState.libraryDateFilter != .none
        return Button {
            showDateFilter = true
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "calendar")
                    .font(.system(size: 9, weight: .medium))
                Text(appState.libraryDateFilter.label)
                    .font(.system(size: 10.5, weight: .medium))
                    .tracking(0.3)
                    .textCase(.uppercase)
                if isActive {
                    Button {
                        withAnimation(AppAnimation.springSnappy) { appState.libraryDateFilter = .none }
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
                option: Binding(get: { appState.libraryDateFilter }, set: { appState.libraryDateFilter = $0 }),
                customStart: Binding(get: { appState.libraryCustomStart }, set: { appState.libraryCustomStart = $0 }),
                customEnd: Binding(get: { appState.libraryCustomEnd }, set: { appState.libraryCustomEnd = $0 }),
                onDismiss: { showDateFilter = false }
            )
            .presentationDetents([.medium])
            .presentationBackground(Color(hex: "F4F6F8"))
            .presentationDragIndicator(.hidden)
        }
    }

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

    // MARK: - Masonry grid

    private var linkGrid: some View {
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
        .task {
            await fetchMissingMetadata()
        }
    }

    // MARK: - Add link panel

    private var addLinkPanel: some View {
        ZStack(alignment: .bottom) {
            Color(hex: "0A0A0B").opacity(0.18)
                .ignoresSafeArea()
                .background(.ultraThinMaterial.opacity(0.3))
                .onTapGesture {
                    withAnimation(AppAnimation.springFluid) { showAddLink = false }
                }

            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Capsule()
                        .fill(Color(hex: "0A0A0B").opacity(0.18))
                        .frame(width: 36, height: 5)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 10)
                .padding(.bottom, 20)

                Text("add link")
                    .font(.system(size: 22, weight: .bold))
                    .tracking(-0.5)
                    .foregroundStyle(AppColors.primaryText)
                    .padding(.bottom, 20)

                HStack(spacing: 10) {
                    TextField("paste or type a URL", text: $pendingURL)
                        .font(.system(size: 14, weight: .regular))
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

                HStack(spacing: 10) {
                    Button {
                        withAnimation(AppAnimation.springFluid) { showAddLink = false }
                    } label: {
                        Text("cancel")
                            .font(.system(size: 15, weight: .regular))
                            .foregroundStyle(AppColors.secondaryText)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(Color(hex: "0A0A0B").opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 13))
                    }
                    .buttonStyle(.plain)

                    Button(action: commitLink) {
                        Text("save")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(
                                LinearGradient(colors: [Color(hex: "1a1a1d"), .black],
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
        guard !Link.samples.contains(where: { $0.id == link.id }),
              let url = URL(string: link.urlString.hasPrefix("http") ? link.urlString : "https://\(link.urlString)") else { return }
        openURL(url)
    }

    private func isValidURL(_ string: String) -> Bool {
        guard !string.isEmpty,
              let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else { return false }
        let range = NSRange(string.startIndex..., in: string)
        return detector.firstMatch(in: string, range: range) != nil
    }

    private func archiveLink(_ link: Link) {
        guard !Link.samples.contains(where: { $0.id == link.id }) else { return }
        withAnimation(AppAnimation.springFluid) { link.isArchived = true }
    }

    private func deleteLink(_ link: Link) {
        guard !Link.samples.contains(where: { $0.id == link.id }) else { return }
        withAnimation(AppAnimation.springFluid) { modelContext.delete(link) }
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
            await MainActor.run {
                if let title = meta.title, !title.isEmpty { link.title = title }
                if let thumb = meta.thumbnailURLString { link.thumbnailURL = thumb }
                if let author = meta.author { link.author = author }
            }
        }
    }

    private func fetchMissingMetadata() async {
        let sampleIDs = Set(Link.samples.map { $0.id })
        let unfetched = savedLinks.filter { !sampleIDs.contains($0.id) && $0.thumbnailURL == nil }
        for link in unfetched {
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

    private let actionWidth: CGFloat = 60
    private let revealThreshold: CGFloat = 44
    private var fullReveal: CGFloat { actionWidth * 2 }

    var body: some View {
        ZStack(alignment: .trailing) {
            if dragOffset < -8 {
                HStack(spacing: 0) {
                    Button {
                        withAnimation(AppAnimation.springFluid) { dragOffset = 0 }
                        onArchive(link)
                    } label: {
                        Image(systemName: "archivebox")
                            .font(.system(size: 14, weight: .light))
                            .foregroundStyle(AppColors.primaryText)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color(hex: "0A0A0B").opacity(0.06))
                    }
                    .buttonStyle(.plain)
                    .frame(width: actionWidth)

                    Button { showDeleteAlert = true } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 14, weight: .light))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(AppColors.destructive)
                    }
                    .buttonStyle(.plain)
                    .frame(width: actionWidth)
                }
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }

            LinkCard(link: link)
                .offset(x: dragOffset)
                .gesture(swipeGesture)
                .onTapGesture {
                    if dragOffset < 0 {
                        withAnimation(AppAnimation.springSnappy) { dragOffset = 0 }
                    } else {
                        onOpen(link)
                    }
                }
                .simultaneousGesture(
                    LongPressGesture(minimumDuration: 0.5)
                        .onEnded { _ in
                            guard dragOffset == 0 else { return }
                            onPeek(link)
                        }
                )
        }
        .alert("Remove link?", isPresented: $showDeleteAlert) {
            Button("Remove", role: .destructive) {
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
