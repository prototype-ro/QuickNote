import SwiftUI

/// Reviewable list of color stamps under the voice player. Tapping a row seeks;
/// tapping the swatch opens a 6-color picker; the label is inline-editable.
struct VoiceStampsSection: View {
    @Bindable var note: Note
    let player: AudioPlayerService
    @State private var editingColorFor: UUID? = nil

    private var sortedMarks: [VoiceMark] {
        note.voiceMarks.sorted { $0.time < $1.time }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(sortedMarks) { mark in
                if let i = note.voiceMarks.firstIndex(where: { $0.id == mark.id }) {
                    VStack(spacing: 8) {
                        HStack(spacing: 10) {
                            Button { editingColorFor = (editingColorFor == mark.id) ? nil : mark.id } label: {
                                Circle().fill(StampPalette.color(for: mark.colorIndex)).frame(width: 16, height: 16)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("cor da marca")

                            Button {
                                if let f = note.audioFileName {
                                    if player.playingFileName != f { player.play(fileName: f) }
                                    player.seek(toFraction: note.audioDuration > 0 ? mark.time / note.audioDuration : 0)
                                }
                            } label: {
                                Text(qnTimeString(mark.time)).appFont(13, .medium).monospacedDigit()
                                    .foregroundStyle(AppColors.primaryText)
                            }
                            .buttonStyle(.plain)

                            TextField("nota", text: $note.voiceMarks[i].label)
                                .appFont(14).foregroundStyle(AppColors.secondaryText)

                            Spacer(minLength: 0)
                            Button { note.voiceMarks.removeAll { $0.id == mark.id } } label: {
                                Image(systemName: "xmark").appFont(11, .regular).foregroundStyle(AppColors.tertiaryText)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("remover marca")
                        }
                        if editingColorFor == mark.id {
                            HStack(spacing: 10) {
                                ForEach(StampPalette.colors.indices, id: \.self) { ci in
                                    Button { note.voiceMarks[i].colorIndex = ci; editingColorFor = nil } label: {
                                        Circle().fill(StampPalette.colors[ci]).frame(width: 22, height: 22)
                                            .overlay(Circle().stroke(AppColors.ink.opacity(mark.colorIndex == ci ? 0.5 : 0), lineWidth: 1.5))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.leading, 26)
                        }
                    }
                }
            }
        }
    }
}
