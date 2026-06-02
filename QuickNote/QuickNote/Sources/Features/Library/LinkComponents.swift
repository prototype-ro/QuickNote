// LinkComponents.swift — MockThumb, PlatformPill, LinkThumbnail, LinkCard

import SwiftUI

// MARK: - MockThumb
// Size-agnostic: no aspect ratio or clip — the containing LinkThumbnail owns those.

struct MockThumb: View {
    let kind: LinkKind

    private var palette: (Color, Color, Color) {
        switch kind {
        case .youtube:   return (Color(hex: "1a1a1d"), Color(hex: "2a2a30"), Color(hex: "16161a"))
        case .tiktok:    return (AppColors.ink, Color(hex: "1a1a22"), Color(hex: "0a0a14"))
        case .instagram: return (Color(hex: "3a2a3a"), Color(hex: "5a3a5a"), Color(hex: "2a1a2a"))
        case .spotify:   return (Color(hex: "0e1a14"), Color(hex: "1a2a20"), Color(hex: "0a140e"))
        case .article:   return (Color(hex: "e8e6e1"), Color(hex: "d8d4cc"), Color(hex: "cdc8be"))
        case .bare:      return (Color(hex: "dcdfe3"), Color(hex: "cdd2d8"), Color(hex: "bec4cc"))
        }
    }

    var body: some View {
        let (c1, c2, c3) = palette
        ZStack {
            LinearGradient(
                colors: [c1, c2, c3],
                startPoint: UnitPoint(x: 0.2, y: 0),
                endPoint: UnitPoint(x: 0.8, y: 1)
            )
            RadialGradient(
                colors: [Color.white.opacity(0.08), .clear],
                center: UnitPoint(x: 0.2, y: 0.1),
                startRadius: 0,
                endRadius: 80
            )
            platformDecal
        }
    }

    @ViewBuilder
    private var platformDecal: some View {
        switch kind {
        case .youtube:
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 44, height: 44)
                Image(systemName: "play.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .offset(x: 1)
            }
        case .tiktok:
            RadialGradient(
                colors: [Color(hex: "25F4EE").opacity(0.15), .clear],
                center: .center, startRadius: 0, endRadius: 60
            )
        case .article:
            Text("A")
                .font(.system(size: 64, weight: .regular, design: .serif))
                .italic()
                .foregroundStyle(AppColors.ink.opacity(0.18))
        case .spotify:
            HStack(alignment: .bottom, spacing: 3) {
                ForEach(0..<8, id: \.self) { i in
                    let heights: [CGFloat] = [8, 16, 24, 14, 20, 10, 18, 12]
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Color.white.opacity(0.18))
                        .frame(width: 4, height: heights[i % heights.count])
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            .padding(14)
        default:
            EmptyView()
        }
    }
}

// MARK: - PlatformPill

struct PlatformPill: View {
    let kind: LinkKind

    private var config: (label: String, bg: Color)? {
        switch kind {
        case .youtube:        return ("YouTube",   Color(hex: "FF3D3D").opacity(0.92))
        case .tiktok:         return ("TikTok",    AppColors.ink.opacity(0.85))
        case .instagram:      return ("Instagram", Color(hex: "E1306C").opacity(0.90))
        case .spotify:        return ("Spotify",   Color(hex: "1DB954").opacity(0.90))
        case .article, .bare: return nil
        }
    }

    var body: some View {
        if let cfg = config {
            Text(cfg.label)
                .appFont(11, .medium, relativeTo: .caption2)
                .tracking(0.3)
                .textCase(.uppercase)
                .foregroundStyle(.white)
                .fixedSize()
                .padding(.horizontal, 12)
                .frame(height: 22)
                .background(cfg.bg)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Color.white.opacity(0.18), lineWidth: 0.5))
        }
    }
}

// MARK: - LinkThumbnail
// The container owns the aspect ratio. The image fills it and is clipped inside.

struct LinkThumbnail: View {
    let link: Link

    // Width-to-height ratio (> 1 = landscape, < 1 = portrait, 1 = square)
    private var containerRatio: CGFloat {
        let isShorts = link.urlString.contains("/shorts/")
        switch link.kind {
        case .youtube:    return isShorts ? 9.0/16.0 : 16.0/9.0
        case .tiktok:     return 9.0/16.0
        case .instagram:  return 4.0/5.0
        case .spotify:    return 1.0
        case .article, .bare: return 3.0/2.0
        }
    }

    var body: some View {
        Color.clear
            .aspectRatio(containerRatio, contentMode: .fit)
            .overlay(thumbnailContent.clipped())
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(AppColors.ink.opacity(0.08), lineWidth: 0.5)
            )
    }

    @ViewBuilder
    private var thumbnailContent: some View {
        if let data = link.thumbnailData, let uiImage = UIImage(data: data) {
            // Locally cached bytes — survives remote URL expiry.
            Image(uiImage: uiImage).resizable().scaledToFill()
        } else if let urlString = link.thumbnailURL, let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                default:
                    MockThumb(kind: link.kind)
                }
            }
        } else {
            MockThumb(kind: link.kind)
        }
    }
}

// MARK: - LinkCard

struct LinkCard: View {
    let link: Link

    private var hasNote: Bool {
        guard let note = link.userNote else { return false }
        return !note.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .topLeading) {
                LinkThumbnail(link: link)

                PlatformPill(kind: link.kind)
                    .padding(8)

                if let duration = link.duration {
                    Text(duration)
                        .appFont(9.5, .medium, relativeTo: .caption2)
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .frame(height: 16)
                        .background(AppColors.ink.opacity(0.78))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                        .padding(6)
                }
            }
            .overlay {
                if hasNote { liquidGlassBorder }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(link.title)
                    .appFont(12, .medium, relativeTo: .caption)
                    .tracking(-0.15)
                    .lineLimit(2)
                    .foregroundStyle(AppColors.primaryText)

                // Fix 4: secondary card text at #6B7280 minimum for accessibility
                HStack(spacing: 5) {
                    Text(link.author ?? link.host)
                        .appFont(10.5, .light, relativeTo: .caption2)
                        .tracking(-0.05)
                        .foregroundStyle(Color(hex: "6B7280"))
                        .lineLimit(1)

                    if let readTime = link.readTime {
                        Text("·")
                            .appFont(10.5, .light, relativeTo: .caption2)
                            .foregroundStyle(Color(hex: "6B7280"))
                        Text(readTime)
                            .appFont(10.5, .light, relativeTo: .caption2)
                            .foregroundStyle(Color(hex: "6B7280"))
                    }
                }
            }
            .padding(.horizontal, 2)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(link.title). \(link.author ?? link.host)")
        .accessibilityHint("double tap to open")
    }

    private var liquidGlassBorder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.28), lineWidth: 7)

            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.75), Color.white.opacity(0.0)],
                        startPoint: .top,
                        endPoint: UnitPoint(x: 0.5, y: 0.55)
                    ),
                    lineWidth: 1.5
                )
        }
    }
}
