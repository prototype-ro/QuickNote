import SwiftUI

/// Static real-waveform bar; the played portion fills sage.
struct StaticWaveform: View {
    let peaks: [Float]
    let progress: Double   // 0...1 played fraction
    var body: some View {
        GeometryReader { geo in
            let n = max(peaks.count, 1)
            let w = max(1.5, (geo.size.width - CGFloat(n) * 2) / CGFloat(n))
            HStack(alignment: .center, spacing: 2) {
                ForEach(peaks.indices, id: \.self) { i in
                    let played = Double(i) / Double(n) <= progress
                    Capsule()
                        .fill(played ? AppColors.voiceAccent : AppColors.voiceAccent.opacity(0.25))
                        .frame(width: w, height: max(3, CGFloat(peaks[i]) * geo.size.height))
                }
            }
            .frame(maxHeight: .infinity, alignment: .center)
        }
    }
}

/// Feed row for a voice note: sage play circle, title/drill, real waveform,
/// duration + relative time, 1-line annotation peek.
struct VoiceCard: View {
    let note: Note
    let onOpen: () -> Void
    @Environment(AudioPlayerService.self) private var player

    private var isThis: Bool { player.playingFileName == note.audioFileName }
    private var isPlaying: Bool { player.isPlaying && isThis }
    private var progress: Double { isThis ? player.progress : 0 }
    private var title: String {
        if note.isTranscribed { return note.displayText ?? note.rawText }
        if let d = note.drill, let drill = RoteiroDrill(rawValue: d) { return drill.label }
        return "gravação"
    }

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: 14) {
                Button {
                    if let f = note.audioFileName { player.toggle(fileName: f) }
                } label: {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .appFont(15, .semibold)
                        .foregroundStyle(AppColors.primaryText)
                        .frame(width: 42, height: 42)
                        .background(AppColors.voiceAccent.opacity(0.28), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isPlaying ? "pausar" : "tocar gravação")

                VStack(alignment: .leading, spacing: 6) {
                    Text(title).appFont(16, .medium).foregroundStyle(AppColors.primaryText).lineLimit(1)
                    StaticWaveform(peaks: note.waveform, progress: progress).frame(height: 22)
                    HStack(spacing: 6) {
                        Text(note.createdAt, format: .relative(presentation: .named))
                        Text("· \(qnTimeString(note.audioDuration))")
                        if !note.voiceAnnotation.isEmpty {
                            Text("· \(note.voiceAnnotation)").lineLimit(1)
                        }
                    }
                    .appFont(12).foregroundStyle(AppColors.secondaryText)
                }
                Spacer(minLength: 0)
            }
            .padding(14)
            .background(CategoryTint.wash(.voice), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(AppColors.hairline, lineWidth: 0.5))
        }
        .buttonStyle(PressStyle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("nota de voz, \(title), \(qnTimeString(note.audioDuration))")
    }
}
