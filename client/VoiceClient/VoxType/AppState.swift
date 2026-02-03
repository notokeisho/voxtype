import SwiftUI
import Combine
import AVFoundation

/// Application state enumeration representing different states of VoxType.
enum AppStatus: Equatable {
    case idle           // Waiting for user action
    case recording      // Currently recording audio
    case processing     // Sending audio to server and waiting for response
    case completed      // Successfully transcribed and pasted
    case error          // An error occurred

    /// SF Symbol name for the current status.
    var iconName: String {
        switch self {
        case .idle:
            return "mic"
        case .recording:
            return "mic.fill"
        case .processing:
            return "ellipsis.circle"
        case .completed:
            return "checkmark.circle"
        case .error:
            return "xmark.circle"
        }
    }

    /// Color for the status icon.
    var iconColor: Color {
        switch self {
        case .idle:
            return .primary
        case .recording:
            return .red
        case .processing:
            return .orange
        case .completed:
            return .green
        case .error:
            return .red
        }
    }

    /// Human-readable status text.
    var displayText: String {
        switch self {
        case .idle:
            return "Ready"
        case .recording:
            return "Recording..."
        case .processing:
            return "Processing..."
        case .completed:
            return "Completed"
        case .error:
            return "Error"
        }
    }

    /// Whether the status should auto-reset to idle.
    var shouldAutoReset: Bool {
        switch self {
        case .completed, .error:
            return true
        default:
            return false
        }
    }
}

/// Observable object that manages the application state.
@MainActor
class AppState: ObservableObject {
    // MARK: - Published Properties

    /// Current application status.
    @Published private(set) var status: AppStatus = .idle

    /// Last error message, if any.
    @Published var lastError: String?

    /// The transcribed text from the last successful transcription.
    @Published var lastTranscribedText: String?

    /// Recording duration in seconds (synced from AudioRecorder).
    @Published private(set) var recordingDuration: TimeInterval = 0

    /// Current audio level for visualization (0.0 to 1.0).
    @Published private(set) var audioLevel: Float = 0

    // MARK: - Services

    /// Audio recorder instance.
    private let audioRecorder = AudioRecorder.shared

    // MARK: - Private Properties

    /// Timer for auto-reset after completion/error.
    private var autoResetTimer: Timer?

    /// Timer for syncing recording state.
    private var syncTimer: Timer?

    /// Cancellables for Combine subscriptions.
    private var cancellables = Set<AnyCancellable>()

    /// Duration before auto-resetting to idle (in seconds).
    private let autoResetDelay: TimeInterval = 3.0

    /// Maximum recording duration (in seconds).
    var maxRecordingDuration: TimeInterval {
        audioRecorder.maxDuration
    }

    // MARK: - Computed Properties

    /// SF Symbol name for the current status icon.
    var statusIcon: String {
        status.iconName
    }

    /// Color for the current status icon.
    var statusColor: Color {
        status.iconColor
    }

    /// Human-readable status text.
    var statusText: String {
        status.displayText
    }

    /// Formatted recording duration string.
    var recordingDurationText: String {
        let seconds = Int(recordingDuration)
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }

    /// URL of the last recording file.
    var lastRecordingURL: URL? {
        audioRecorder.recordingURL
    }

    // MARK: - Initialization

    init() {
        setupBindings()
    }

    private func setupBindings() {
        // Sync recording duration from AudioRecorder
        audioRecorder.$recordingDuration
            .receive(on: DispatchQueue.main)
            .assign(to: &$recordingDuration)

        // Handle recording errors
        audioRecorder.$errorMessage
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] error in
                self?.setError(error)
            }
            .store(in: &cancellables)
    }

    // MARK: - State Transitions

    /// Start recording audio.
    /// - Returns: `true` if recording started successfully.
    @discardableResult
    func startRecording() -> Bool {
        cancelTimers()

        guard audioRecorder.startRecording() else {
            setError(audioRecorder.errorMessage ?? "Failed to start recording")
            return false
        }

        status = .recording
        lastError = nil

        // Start sync timer for audio level updates
        syncTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self, self.status == .recording else { return }
                self.audioLevel = self.audioRecorder.getCurrentLevel()
            }
        }

        return true
    }

    /// Stop recording and return the audio file URL.
    /// - Returns: URL of the recorded audio file.
    @discardableResult
    func stopRecording() -> URL? {
        guard status == .recording else { return nil }

        syncTimer?.invalidate()
        syncTimer = nil
        audioLevel = 0

        let url = audioRecorder.stopRecording()
        status = .processing

        return url
    }

    /// Cancel recording without processing.
    func cancelRecording() {
        guard status == .recording else { return }

        syncTimer?.invalidate()
        syncTimer = nil
        audioLevel = 0

        audioRecorder.cancelRecording()
        status = .idle
    }

    /// Mark transcription as completed.
    func completeTranscription(text: String) {
        status = .completed
        lastTranscribedText = text
        lastError = nil

        // Cleanup recording file
        audioRecorder.cleanupRecording()

        scheduleAutoReset()
    }

    /// Set error state with a message.
    func setError(_ message: String) {
        status = .error
        lastError = message

        // Cleanup recording file on error
        audioRecorder.cleanupRecording()

        scheduleAutoReset()
    }

    /// Reset the state to idle.
    func reset() {
        cancelTimers()
        status = .idle
        lastError = nil
        audioLevel = 0
    }

    /// Check and request microphone permission.
    func checkMicrophonePermission() async -> Bool {
        await audioRecorder.requestMicrophonePermission()
    }

    // MARK: - Private Methods

    /// Schedule auto-reset to idle after delay.
    private func scheduleAutoReset() {
        autoResetTimer?.invalidate()
        autoResetTimer = Timer.scheduledTimer(withTimeInterval: autoResetDelay, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.reset()
            }
        }
    }

    /// Cancel all timers.
    private func cancelTimers() {
        autoResetTimer?.invalidate()
        autoResetTimer = nil
        syncTimer?.invalidate()
        syncTimer = nil
    }

    deinit {
        autoResetTimer?.invalidate()
        syncTimer?.invalidate()
    }
}
