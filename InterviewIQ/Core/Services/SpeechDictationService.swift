//
//  SpeechDictationService.swift
//  InterviewIQ
//
//  Live speech-to-text for interview notes using Apple's Speech framework
//  (the native iOS equivalent of "voice typing"). Recognition runs on-device
//  where supported and needs no API key. Drives observable UI, so it stays on
//  the main actor; audio capture happens on the engine's own thread.
//

import Foundation
import Speech
import AVFoundation

@Observable
final class SpeechDictationService {

    enum Status: Equatable {
        case idle          // ready, not listening
        case recording     // actively transcribing
        case unavailable   // no recognizer on this device/locale
        case denied        // mic or speech permission refused
    }

    private(set) var status: Status = .idle
    /// The latest (possibly partial) transcript for the current dictation.
    private(set) var transcript: String = ""
    private(set) var errorMessage: String?

    var isRecording: Bool { status == .recording }

    private let recognizer = SFSpeechRecognizer()
    private let audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    // See [[interviewiq-mainactor-deinit-crash]] — synchronous deinit under the
    // project's MainActor-isolation default. The audio engine tears itself down.
    nonisolated deinit {}

    func toggle() async {
        if isRecording { stop() } else { await start() }
    }

    func start() async {
        guard status != .recording else { return }
        errorMessage = nil
        transcript = ""

        guard let recognizer, recognizer.isAvailable else {
            status = .unavailable
            errorMessage = "Speech recognition isn't available on this device right now."
            return
        }

        guard await Self.requestAuthorization() else {
            status = .denied
            errorMessage = "Allow Microphone and Speech Recognition in Settings to dictate notes."
            return
        }

        do {
            try beginAudio(recognizer: recognizer)
            status = .recording
        } catch {
            status = .idle
            errorMessage = "Couldn't start dictation: \(error.localizedDescription)"
            cleanup()
        }
    }

    func stop() {
        guard status == .recording else { return }
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.cancel()
        status = .idle
        cleanup()
    }

    // MARK: - Private

    private func beginAudio(recognizer: SFSpeechRecognizer) throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: .duckOthers)
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        self.request = request

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak request] buffer, _ in
            request?.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()

        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            // Recognition callbacks arrive off the main actor; hop back to update UI.
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let result {
                    self.transcript = result.bestTranscription.formattedString
                    if result.isFinal { self.stop() }
                }
                if error != nil { self.stop() }
            }
        }
    }

    private func cleanup() {
        request = nil
        task = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    /// Requests both Speech-recognition and Microphone permission. Returns true
    /// only if both are granted.
    private static func requestAuthorization() async -> Bool {
        let speechStatus: SFSpeechRecognizerAuthorizationStatus = await withCheckedContinuation { cont in
            SFSpeechRecognizer.requestAuthorization { cont.resume(returning: $0) }
        }
        guard speechStatus == .authorized else { return false }

        return await withCheckedContinuation { cont in
            AVAudioApplication.requestRecordPermission { cont.resume(returning: $0) }
        }
    }
}
