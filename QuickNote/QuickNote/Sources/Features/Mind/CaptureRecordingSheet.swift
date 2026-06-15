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
    let onSave: (_ fileName: String, _ duration: TimeInterval, _ waveform: [Float], _ drill: RoteiroDrill?) -> Void

    @State private var recorder = AudioRecorderService()
    @State private var selectedDrill: RoteiroDrill? = nil
    private var isRecording: Bool { recorder.state == .recording }

    var body: some View {
        VStack(spacing: 20) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    DrillChip(label: "livre", selected: selectedDrill == nil) { selectedDrill = nil }
                    ForEach(RoteiroDrill.allCases) { d in
                        DrillChip(label: d.label, selected: selectedDrill == d) { selectedDrill = d }
                    }
                }.padding(.horizontal, 16)
            }
            .disabled(isRecording).opacity(isRecording ? 0.4 : 1)

            Spacer(minLength: 0)
            Text(qnTimeString(recorder.elapsed))
                .appFont(36, .light, relativeTo: .largeTitle)
                .monospacedDigit()
                .foregroundStyle(AppColors.primaryText)
            LevelBar(level: recorder.level).frame(height: 26).padding(.horizontal, 44)
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

            if recorder.state == .denied {
                Text("acesso ao microfone negado — habilite em ajustes")
                    .appFont(13)
                    .foregroundStyle(AppColors.secondaryText)
            }
            Spacer(minLength: 6)
        }
        .padding(.top, 20)
    }

    private func toggle() async {
        switch recorder.state {
        case .idle, .denied: await recorder.start()
        case .recording:
            if let r = recorder.stop() {
                HapticEngine.submit()
                onSave(r.fileName, r.duration, r.waveform, selectedDrill)
                dismiss()
            }
        }
    }
}
