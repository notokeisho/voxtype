import SwiftUI

/// Application state enumeration representing different states of the voice client.
enum AppStatus {
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
}

/// Observable object that manages the application state.
@MainActor
class AppState: ObservableObject {
    /// Current application status.
    @Published var status: AppStatus = .idle

    /// Last error message, if any.
    @Published var lastError: String?

    /// Whether the user is authenticated.
    @Published var isAuthenticated: Bool = false

    /// The transcribed text from the last successful transcription.
    @Published var lastTranscribedText: String?

    /// SF Symbol name for the current status icon.
    var statusIcon: String {
        status.iconName
    }

    /// Reset the state to idle.
    func reset() {
        status = .idle
        lastError = nil
    }

    /// Set error state with a message.
    func setError(_ message: String) {
        status = .error
        lastError = message
    }
}
