import SwiftUI

// MARK: - Live mic level bar
struct LevelBar: View {
    let level: CGFloat
    private let bars = 28
    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 3) {
                ForEach(0..<bars, id: \.self) { i in
                    let threshold = CGFloat(i) / CGFloat(bars)
                    Capsule()
                        .fill(level >= threshold ? AppColors.voiceAccent : AppColors.ink.opacity(0.12))
                        .frame(width: max(2, (geo.size.width - CGFloat(bars) * 3) / CGFloat(bars)))
                }
            }
            .frame(maxHeight: .infinity, alignment: .center)
            .animation(.easeOut(duration: 0.08), value: level)
        }
    }
}

// MARK: - Drill chip
struct DrillChip: View {
    let label: String
    let selected: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(label)
                .appFont(15, .medium)
                .foregroundStyle(selected ? AppColors.voiceAccent : AppColors.secondaryText)
                .padding(.vertical, 7).padding(.horizontal, 14)
                .background(Capsule().fill(selected
                    ? AppColors.voiceAccent.opacity(0.18)
                    : AppColors.ink.opacity(0.06)))
        }
        .buttonStyle(.plain)
    }
}

func qnTimeString(_ t: TimeInterval) -> String {
    let s = Int(t); return String(format: "%02d:%02d", s / 60, s % 60)
}

// MARK: - Capture sheet
struct CaptureRecordingSheet: View {
    @Environment(\.dismiss) private var dismiss
    private let coordinator = RecordingCoordinator.shared

    @State private var selectedDrill: RoteiroDrill? = nil
    private var isRecording: Bool { coordinator.state == .recording }

    var body: some View {
        VStack(spacing: 20) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    DrillChip(label: "livre", selected: selectedDrill == nil) {
                        selectedDrill = nil
                        coordinator.selectedDrill = nil
                    }
                    ForEach(RoteiroDrill.allCases) { d in
                        DrillChip(label: d.label, selected: selectedDrill == d) {
                            selectedDrill = d
                            coordinator.selectedDrill = d
                        }
                    }
                }.padding(.horizontal, 16)
            }
            .disabled(isRecording).opacity(isRecording ? 0.4 : 1)

            Spacer(minLength: 0)
            Text(qnTimeString(coordinator.elapsed))
                .appFont(36, .light, relativeTo: .largeTitle)
                .monospacedDigit()
                .foregroundStyle(AppColors.primaryText)
            LevelBar(level: coordinator.level).frame(height: 26).padding(.horizontal, 44)
            Spacer(minLength: 0)

            Button { Task { await toggle() } } label: {
                ZStack {
                    Circle().fill(isRecording ? Color(hex: "EF4444").opacity(0.14)
                                              : AppColors.voiceAccent.opacity(0.28))
                        .frame(width: 80, height: 80)
                    RoundedRectangle(cornerRadius: isRecording ? 7 : 28, style: .continuous)
                        .fill(isRecording ? Color(hex: "EF4444") : AppColors.primaryText)
                        .frame(width: isRecording ? 28 : 54, height: isRecording ? 28 : 54)
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isRecording)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isRecording ? "parar gravação" : "iniciar gravação")

            if coordinator.state == .denied {
                Text("acesso ao microfone negado — habilite em ajustes")
                    .appFont(13)
                    .foregroundStyle(AppColors.secondaryText)
            }
            Spacer(minLength: 6)
        }
        .padding(.top, 20)
    }

    private func toggle() async {
        switch coordinator.state {
        case .idle, .denied:
            coordinator.selectedDrill = selectedDrill
            await coordinator.start()
        case .recording:
            HapticEngine.submit()
            coordinator.stop()
            dismiss()
        }
    }
}

// MARK: - PlayerPanel (detail playback with real-waveform scrubber)
struct PlayerPanel: View {
    let fileName: String
    let peaks: [Float]
    let duration: TimeInterval
    let player: AudioPlayerService

    private var isThis: Bool { player.playingFileName == fileName }
    private var isPlaying: Bool { player.isPlaying && isThis }
    private var progress: Double { isThis ? player.progress : 0 }
    private var elapsed: TimeInterval { isThis ? player.currentTime : 0 }

    var body: some View {
        HStack(spacing: 14) {
            Button { player.toggle(fileName: fileName) } label: {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .appFont(16, .semibold).foregroundStyle(AppColors.primaryText)
                    .frame(width: 46, height: 46)
                    .background(AppColors.voiceAccent.opacity(0.28), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isPlaying ? "pausar" : "tocar gravação")

            VStack(spacing: 6) {
                GeometryReader { geo in
                    StaticWaveform(peaks: peaks, progress: progress)
                        .contentShape(Rectangle())
                        .gesture(DragGesture(minimumDistance: 0).onChanged { v in
                            if isThis { player.seek(toFraction: min(1, max(0, v.location.x / geo.size.width))) }
                        })
                }
                .frame(height: 26)
                HStack {
                    Text(qnTimeString(elapsed)).monospacedDigit(); Spacer()
                    Text(qnTimeString(duration)).monospacedDigit()
                }
                .appFont(12).foregroundStyle(AppColors.secondaryText)
            }
        }
        .padding(14)
        .background(CategoryTint.wash(.voice), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// MARK: - ReviewEditor (optional roteiro review loop)
struct ReviewEditor: View {
    @Binding var review: VoiceReview
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("\"tipo / né / então\"").appFont(15).foregroundStyle(AppColors.secondaryText)
                Spacer()
                Stepper(value: Binding(get: { review.fillerCount ?? 0 },
                                       set: { review.fillerCount = $0 }), in: 0...99) {
                    Text("\(review.fillerCount ?? 0)").monospacedDigit().foregroundStyle(AppColors.primaryText)
                }
                .labelsHidden()
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("ritmo").appFont(15).foregroundStyle(AppColors.secondaryText)
                HStack(spacing: 8) {
                    ForEach(RecordingPace.allCases) { p in
                        DrillChip(label: p.label, selected: review.pace == p.rawValue) {
                            review.pace = (review.pace == p.rawValue) ? nil : p.rawValue
                        }
                    }
                }
            }
            quietField("1 coisa que melhorou", text: $review.improved)
            quietField("1 coisa pra focar", text: $review.focusNext)
        }
    }
    private func quietField(_ placeholder: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text, axis: .vertical).appFont(16).padding(12)
            .background(AppColors.ink.opacity(0.05), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
