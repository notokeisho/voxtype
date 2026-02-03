import Foundation
import UserNotifications

/// Notification category identifiers.
enum NotificationCategory: String {
    case error = "ERROR"
    case success = "SUCCESS"
    case warning = "WARNING"
}

/// Manager for macOS notifications.
@MainActor
class NotificationManager: ObservableObject {
    /// Shared instance.
    static let shared = NotificationManager()

    // MARK: - Published Properties

    /// Whether notification permission is granted.
    @Published private(set) var isAuthorized = false

    // MARK: - Private Properties

    /// The notification center.
    private let notificationCenter = UNUserNotificationCenter.current()

    private init() {
        checkAuthorizationStatus()
    }

    // MARK: - Authorization

    /// Check current notification authorization status.
    func checkAuthorizationStatus() {
        notificationCenter.getNotificationSettings { [weak self] settings in
            Task { @MainActor in
                self?.isAuthorized = settings.authorizationStatus == .authorized
            }
        }
    }

    /// Request notification permission.
    func requestAuthorization() async -> Bool {
        do {
            let granted = try await notificationCenter.requestAuthorization(options: [.alert, .sound, .badge])
            isAuthorized = granted
            return granted
        } catch {
            print("Notification authorization error: \(error)")
            return false
        }
    }

    // MARK: - Show Notifications

    /// Show an error notification.
    /// Only shows for critical errors that require user attention.
    /// - Parameter message: The error message to display.
    func showError(_ message: String) {
        showNotification(
            title: "VoxType Error",
            body: message,
            category: .error
        )
    }

    /// Show a success notification.
    /// - Parameter message: The success message to display.
    func showSuccess(_ message: String) {
        showNotification(
            title: "VoxType",
            body: message,
            category: .success
        )
    }

    /// Show a warning notification.
    /// - Parameter message: The warning message to display.
    func showWarning(_ message: String) {
        showNotification(
            title: "VoxType Warning",
            body: message,
            category: .warning
        )
    }

    /// Show a notification for authentication errors.
    func showAuthError() {
        showNotification(
            title: "Authentication Required",
            body: "Please log in to continue using VoxType",
            category: .error
        )
    }

    /// Show a notification for server connection errors.
    func showServerError() {
        showNotification(
            title: "Server Unavailable",
            body: "Cannot connect to the transcription server. Please check your connection.",
            category: .error
        )
    }

    /// Show a notification for network errors.
    func showNetworkError() {
        showNotification(
            title: "Network Error",
            body: "Please check your internet connection",
            category: .error
        )
    }

    // MARK: - Private Methods

    private func showNotification(title: String, body: String, category: NotificationCategory) {
        guard isAuthorized else {
            // Try to request authorization
            Task {
                let granted = await requestAuthorization()
                if granted {
                    showNotification(title: title, body: body, category: category)
                }
            }
            return
        }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = category == .error ? .default : nil
        content.categoryIdentifier = category.rawValue

        // Create a unique identifier
        let identifier = "\(category.rawValue)-\(UUID().uuidString)"

        // Create the request
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: nil // Deliver immediately
        )

        // Add the request
        notificationCenter.add(request) { error in
            if let error = error {
                print("Failed to show notification: \(error)")
            }
        }
    }

    /// Remove all delivered notifications.
    func clearAllNotifications() {
        notificationCenter.removeAllDeliveredNotifications()
    }

    /// Remove all pending notifications.
    func clearPendingNotifications() {
        notificationCenter.removeAllPendingNotificationRequests()
    }
}

// MARK: - API Error Extension

extension APIError {
    /// Show appropriate notification for this error.
    @MainActor
    func showNotificationIfNeeded() {
        let manager = NotificationManager.shared

        switch self {
        case .notAuthenticated, .unauthorized:
            manager.showAuthError()

        case .notWhitelisted:
            manager.showError("You are not authorized to use this service")

        case .serverUnavailable:
            manager.showServerError()

        case .networkError:
            manager.showNetworkError()

        case .serverError(let message):
            manager.showError(message)

        // These errors don't need notifications (handled by UI)
        case .invalidURL, .invalidResponse, .badRequest,
             .fileTooLarge, .unsupportedFormat:
            break
        }
    }
}
