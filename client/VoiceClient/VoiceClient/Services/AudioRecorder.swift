import Foundation
import AVFoundation

/// Audio recorder for capturing voice input.
/// Records in WAV format (16kHz, mono, 16-bit) for whisper.cpp compatibility.
@MainActor
class AudioRecorder: NSObject, ObservableObject {
    /// Shared instance.
    static let shared = AudioRecorder()

    // MARK: - Published Properties

    /// Whether recording is currently in progress.
    @Published private(set) var isRecording = false

    /// Current recording duration in seconds.
    @Published private(set) var recordingDuration: TimeInterval = 0

    /// Last error message.
    @Published var errorMessage: String?

    // MARK: - Configuration

    /// Maximum recording duration in seconds.
    let maxDuration: TimeInterval = 60.0

    /// Audio format settings for whisper.cpp compatibility.
    private let audioSettings: [String: Any] = [
        AVFormatIDKey: Int(kAudioFormatLinearPCM),
        AVSampleRateKey: 16000.0,
        AVNumberOfChannelsKey: 1,
        AVLinearPCMBitDepthKey: 16,
        AVLinearPCMIsFloatKey: false,
        AVLinearPCMIsBigEndianKey: false,
        AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
    ]

    // MARK: - Private Properties

    /// Audio recorder instance.
    private var audioRecorder: AVAudioRecorder?

    /// Timer for tracking recording duration.
    private var durationTimer: Timer?

    /// Timer for max duration limit.
    private var maxDurationTimer: Timer?

    /// URL of the current/last recording.
    private(set) var recordingURL: URL?

    /// Callback when recording is stopped (either manually or by max duration).
    var onRecordingStopped: ((URL?) -> Void)?

    // MARK: - Initialization

    private override init() {
        super.init()
    }

    // MARK: - Public Methods

    /// Start recording audio.
    /// - Returns: `true` if recording started successfully.
    @discardableResult
    func startRecording() -> Bool {
        // Check microphone permission
        guard checkMicrophonePermission() else {
            errorMessage = "Microphone permission not granted"
            return false
        }

        // Stop any existing recording
        if isRecording {
            stopRecording()
        }

        // Create temporary file URL for recording
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "voice_recording_\(UUID().uuidString).wav"
        let fileURL = tempDir.appendingPathComponent(fileName)
        recordingURL = fileURL

        do {
            // Create and configure audio recorder
            audioRecorder = try AVAudioRecorder(url: fileURL, settings: audioSettings)
            audioRecorder?.delegate = self
            audioRecorder?.isMeteringEnabled = true

            // Start recording
            guard audioRecorder?.record() == true else {
                errorMessage = "Failed to start recording"
                return false
            }

            isRecording = true
            recordingDuration = 0
            errorMessage = nil

            // Start duration timer
            startDurationTimer()

            // Start max duration timer
            startMaxDurationTimer()

            return true
        } catch {
            errorMessage = "Recording error: \(error.localizedDescription)"
            return false
        }
    }

    /// Stop recording and return the audio file URL.
    /// - Returns: URL of the recorded audio file, or `nil` if no recording was in progress.
    @discardableResult
    func stopRecording() -> URL? {
        guard isRecording else { return nil }

        // Stop timers
        stopTimers()

        // Stop recording
        audioRecorder?.stop()
        isRecording = false

        let url = recordingURL

        // Notify callback
        onRecordingStopped?(url)

        return url
    }

    /// Cancel recording and delete the temporary file.
    func cancelRecording() {
        guard isRecording else { return }

        stopTimers()
        audioRecorder?.stop()
        isRecording = false

        // Delete the temporary file
        if let url = recordingURL {
            try? FileManager.default.removeItem(at: url)
        }
        recordingURL = nil
    }

    /// Delete the recording file after it has been processed.
    func cleanupRecording() {
        if let url = recordingURL {
            try? FileManager.default.removeItem(at: url)
            recordingURL = nil
        }
    }

    /// Get current audio level (0.0 to 1.0).
    func getCurrentLevel() -> Float {
        guard let recorder = audioRecorder, isRecording else { return 0 }
        recorder.updateMeters()
        let decibels = recorder.averagePower(forChannel: 0)
        // Convert decibels to linear scale (0.0 to 1.0)
        // Typical range is -160 dB (silence) to 0 dB (max)
        let minDecibels: Float = -60.0
        let normalized = max(0, (decibels - minDecibels) / (-minDecibels))
        return normalized
    }

    // MARK: - Permission Handling

    /// Check if microphone permission is granted.
    /// Note: Permission should be requested on app launch, not during recording.
    func checkMicrophonePermission() -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return true
        case .notDetermined:
            // Don't request here - should be requested on app launch
            // Return false to prevent recording without permission
            return false
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }

    /// Request microphone permission.
    func requestMicrophonePermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    // MARK: - Private Methods

    private func startDurationTimer() {
        durationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self, self.isRecording else { return }
                self.recordingDuration += 0.1
            }
        }
    }

    private func startMaxDurationTimer() {
        maxDurationTimer = Timer.scheduledTimer(withTimeInterval: maxDuration, repeats: false) { [weak self] _ in
            Task { @MainActor in
                guard let self = self, self.isRecording else { return }
                // Auto-stop when max duration reached
                _ = self.stopRecording()
            }
        }
    }

    private func stopTimers() {
        durationTimer?.invalidate()
        durationTimer = nil
        maxDurationTimer?.invalidate()
        maxDurationTimer = nil
    }
}

// MARK: - AVAudioRecorderDelegate

extension AudioRecorder: AVAudioRecorderDelegate {
    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        Task { @MainActor in
            if !flag {
                errorMessage = "Recording did not finish successfully"
            }
        }
    }

    nonisolated func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        Task { @MainActor in
            if let error = error {
                errorMessage = "Recording error: \(error.localizedDescription)"
            }
        }
    }
}
