// VoiceCaptureManager.swift — hold-to-record via SFSpeechRecognizer

import Foundation
import Speech
import AVFoundation

@Observable
final class VoiceCaptureManager {
    private(set) var isRecording = false
    private(set) var transcribedText = ""
    private(set) var errorMessage: String? = nil

    private var recognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    init() {
        recognizer = SFSpeechRecognizer(locale: Locale.current)
    }

    func startRecording() {
        guard !isRecording else { return }
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                guard let self else { return }
                if status == .authorized {
                    self.beginRecognition()
                } else {
                    self.showError()
                }
            }
        }
    }

    func stopRecording() {
        guard isRecording else { return }
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        isRecording = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    func clearTranscription() {
        transcribedText = ""
    }

    // MARK: - Private

    private func beginRecognition() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)

            recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
            guard let req = recognitionRequest else { return }
            req.shouldReportPartialResults = true

            let inputNode = audioEngine.inputNode
            recognitionTask = recognizer?.recognitionTask(with: req) { [weak self] result, error in
                guard let self else { return }
                DispatchQueue.main.async {
                    if let result {
                        self.transcribedText = result.bestTranscription.formattedString
                    }
                    if error != nil || result?.isFinal == true {
                        self.stopRecording()
                    }
                }
            }

            let fmt = inputNode.outputFormat(forBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: fmt) { [weak self] buffer, _ in
                self?.recognitionRequest?.append(buffer)
            }

            audioEngine.prepare()
            try audioEngine.start()
            isRecording = true
        } catch {
            showError()
        }
    }

    private func showError() {
        errorMessage = "couldn't catch that, try again"
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            self?.errorMessage = nil
        }
    }
}
