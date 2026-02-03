import Foundation
import AppKit
import Carbon

/// Manager for clipboard operations with automatic paste functionality.
@MainActor
class ClipboardManager: ObservableObject {
    /// Shared instance.
    static let shared = ClipboardManager()

    // MARK: - Private Properties

    /// The system pasteboard.
    private let pasteboard = NSPasteboard.general

    /// Stored clipboard content for restoration.
    private var savedContent: [NSPasteboard.PasteboardType: Data] = [:]

    /// Delay before pasting (to ensure clipboard is updated).
    private let pasteDelay: TimeInterval = 0.05

    /// Delay before restoring original clipboard content.
    private let restoreDelay: TimeInterval = 0.1

    private init() {}

    // MARK: - Public Methods

    /// Paste text at the current cursor position.
    /// This saves the current clipboard, sets the new text, simulates Cmd+V, and restores the original clipboard.
    /// - Parameter text: The text to paste.
    func pasteText(_ text: String) {
        // 1. Save current clipboard content
        saveClipboard()

        // 2. Set new text to clipboard
        setClipboardText(text)

        // 3. Simulate Cmd+V after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + pasteDelay) { [weak self] in
            self?.simulatePaste()

            // 4. Restore original clipboard after paste is complete
            DispatchQueue.main.asyncAfter(deadline: .now() + (self?.restoreDelay ?? 0.1)) { [weak self] in
                self?.restoreClipboard()
            }
        }
    }

    /// Copy text to clipboard without pasting.
    /// - Parameter text: The text to copy.
    func copyText(_ text: String) {
        setClipboardText(text)
    }

    /// Get the current clipboard text.
    /// - Returns: The current clipboard text, or nil if not available.
    func getClipboardText() -> String? {
        pasteboard.string(forType: .string)
    }

    // MARK: - Private Methods

    /// Save the current clipboard content.
    private func saveClipboard() {
        savedContent.removeAll()

        // Save all available types
        guard let types = pasteboard.types else { return }

        for type in types {
            if let data = pasteboard.data(forType: type) {
                savedContent[type] = data
            }
        }
    }

    /// Set text to the clipboard.
    private func setClipboardText(_ text: String) {
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    /// Restore the saved clipboard content.
    private func restoreClipboard() {
        guard !savedContent.isEmpty else { return }

        pasteboard.clearContents()

        for (type, data) in savedContent {
            pasteboard.setData(data, forType: type)
        }

        savedContent.removeAll()
    }

    /// Simulate Cmd+V key press to paste.
    private func simulatePaste() {
        // Create key down event for 'V' with Command modifier
        let keyCode: CGKeyCode = 9 // V key

        // Key down
        if let keyDownEvent = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true) {
            keyDownEvent.flags = .maskCommand
            keyDownEvent.post(tap: .cghidEventTap)
        }

        // Key up
        if let keyUpEvent = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false) {
            keyUpEvent.flags = .maskCommand
            keyUpEvent.post(tap: .cghidEventTap)
        }
    }
}

// MARK: - Convenience Extensions

extension ClipboardManager {
    /// Paste text with a callback when complete.
    /// - Parameters:
    ///   - text: The text to paste.
    ///   - completion: Callback when paste operation is complete.
    func pasteText(_ text: String, completion: @escaping () -> Void) {
        // 1. Save current clipboard content
        saveClipboard()

        // 2. Set new text to clipboard
        setClipboardText(text)

        // 3. Simulate Cmd+V after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + pasteDelay) { [weak self] in
            self?.simulatePaste()

            // 4. Restore original clipboard and call completion
            DispatchQueue.main.asyncAfter(deadline: .now() + (self?.restoreDelay ?? 0.1)) { [weak self] in
                self?.restoreClipboard()
                completion()
            }
        }
    }

    /// Check if the app has permission to simulate key events.
    /// - Returns: `true` if accessibility permission is granted.
    var canSimulateKeyEvents: Bool {
        // CGEvent posting requires accessibility permission
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }
}
