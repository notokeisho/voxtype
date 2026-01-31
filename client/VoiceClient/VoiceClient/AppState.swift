import SwiftUI
import Combine

/// Application state enumeration representing different states of the voice client.
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

    /// Recording duration in seconds.
    @Published private(set) var recordingDuration: TimeInterval = 0

    // MARK: - Private Properties

    /// Timer for auto-reset after completion/error.
    private var autoResetTimer: Timer?

    /// Timer for tracking recording duration.
    private var recordingTimer: Timer?

    /// Duration before auto-resetting to idle (in seconds).
    private let autoResetDelay: TimeInterval = 3.0

    /// Maximum recording duration (in seconds).
    let maxRecordingDuration: TimeInterval = 60.0

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

    // MARK: - State Transitions

    /// Start recording.
    func startRecording() {
        cancelTimers()
        status = .recording
        recordingDuration = 0

        // Start duration timer
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                self.recordingDuration += 0.1

                // Auto-stop at max duration
                if self.recordingDuration >= self.maxRecordingDuration {
                    self.stopRecording()
                }
            }
        }
    }

    /// Stop recording and start processing.
    func stopRecording() {
        guard status == .recording else { return }
        recordingTimer?.invalidate()
        recordingTimer = nil
        status = .processing
    }

    /// Mark transcription as completed.
    func completeTranscription(text: String) {
        status = .completed
        lastTranscribedText = text
        lastError = nil
        scheduleAutoReset()
    }

    /// Set error state with a message.
    func setError(_ message: String) {
        status = .error
        lastError = message
        scheduleAutoReset()
    }

    /// Reset the state to idle.
    func reset() {
        cancelTimers()
        status = .idle
        lastError = nil
        recordingDuration = 0
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
        recordingTimer?.invalidate()
        recordingTimer = nil
    }

    deinit {
        autoResetTimer?.invalidate()
        recordingTimer?.invalidate()
    }
}
