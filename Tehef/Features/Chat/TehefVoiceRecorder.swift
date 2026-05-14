import AVFoundation
import Foundation

@MainActor
@Observable
final class TehefVoiceRecorder {
    private var recorder: AVAudioRecorder?
    private var timer: Timer?
    private var startedAt: Date?
    private var outputURL: URL?

    var isRecording = false
    var elapsed: TimeInterval = 0
    var errorMessage: String?

    func startRecording() async {
        errorMessage = nil

        let granted = await requestMicrophonePermission()
        guard granted else {
            errorMessage = "Microphone access is required to send voice messages."
            return
        }

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetoothHFP])
            try session.setActive(true)

            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("voice-\(UUID().uuidString).m4a")
            outputURL = url

            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44_100,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue,
            ]

            recorder = try AVAudioRecorder(url: url, settings: settings)
            recorder?.isMeteringEnabled = true
            recorder?.prepareToRecord()
            recorder?.record()

            startedAt = Date()
            elapsed = 0
            isRecording = true
            startTimer()
        } catch {
            errorMessage = error.localizedDescription
            cleanupRecordingState()
        }
    }

    func cancelRecording() {
        stopRecorder()
        deleteOutputFile()
        cleanupRecordingState()
    }

    func finishRecording() -> Data? {
        stopRecorder()
        defer { cleanupRecordingState() }

        guard let startedAt else { return nil }
        let duration = Date().timeIntervalSince(startedAt)
        guard duration >= 0.5 else {
            errorMessage = "Hold to record a longer voice message."
            deleteOutputFile()
            return nil
        }

        guard let outputURL, let data = try? Data(contentsOf: outputURL) else {
            errorMessage = "Could not read the voice recording."
            return nil
        }

        deleteOutputFile()
        return data
    }

    private func requestMicrophonePermission() async -> Bool {
        if #available(iOS 17.0, *) {
            return await AVAudioApplication.requestRecordPermission()
        }

        return await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, let startedAt = self.startedAt else { return }
                self.elapsed = Date().timeIntervalSince(startedAt)
            }
        }
    }

    private func stopRecorder() {
        timer?.invalidate()
        timer = nil
        recorder?.stop()
        recorder = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func deleteOutputFile() {
        guard let outputURL else { return }
        try? FileManager.default.removeItem(at: outputURL)
        self.outputURL = nil
    }

    private func cleanupRecordingState() {
        isRecording = false
        elapsed = 0
        startedAt = nil
    }
}
