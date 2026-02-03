import SwiftUI
import AppKit

/// A floating overlay window that displays the audio visualizer during recording.
/// This window is always on top, does not steal focus, and ignores mouse events.
class RecordingOverlayWindow: NSPanel {
    /// Shared instance for global access.
    static let shared = RecordingOverlayWindow()

    /// The hosting view for SwiftUI content.
    private var hostingView: NSHostingView<AnyView>?

    /// Reference to app state for audio level updates.
    private weak var appState: AppState?

    /// Window width.
    private let windowWidth: CGFloat = 200

    /// Window height.
    private let windowHeight: CGFloat = 50

    /// Corner radius for the window background.
    private let cornerRadius: CGFloat = 10

    // MARK: - Overrides for non-activating behavior

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    private init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: windowWidth, height: windowHeight),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        configureWindow()
    }

    // MARK: - Configuration

    private func configureWindow() {
        // Always on top
        level = .floating

        // Transparent background (we'll draw our own)
        isOpaque = false
        backgroundColor = .clear

        // Click-through (ignore all mouse events)
        ignoresMouseEvents = true

        // Don't show in Expose or Spaces
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]

        // Hide from screen capture if desired
        sharingType = .none

        // Position at top center of screen
        positionAtTopCenter()
    }

    /// Position the window at the top center of the main screen.
    private func positionAtTopCenter() {
        guard let screen = NSScreen.main else { return }

        let screenFrame = screen.visibleFrame
        let x = screenFrame.midX - (windowWidth / 2)
        let y = screenFrame.maxY - windowHeight - 20 // 20pt below menu bar

        setFrameOrigin(NSPoint(x: x, y: y))
    }

    // MARK: - Public Methods

    /// Set up the window with the app state for audio level updates.
    func setup(appState: AppState) {
        self.appState = appState
        updateContent()
    }

    /// Show the window with fade-in animation.
    func showWithAnimation() {
        guard appState != nil else { return }

        // Ensure we're on the main thread
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            // Update content with current app state
            self.updateContent()

            // Reposition in case screen configuration changed
            self.positionAtTopCenter()

            // Start with zero opacity
            self.alphaValue = 0

            // Show the window
            self.orderFrontRegardless()

            // Fade in
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.2
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                self.animator().alphaValue = 1.0
            }
        }
    }

    /// Hide the window with fade-out animation.
    func hideWithAnimation() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            // Fade out
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.2
                context.timingFunction = CAMediaTimingFunction(name: .easeIn)
                self.animator().alphaValue = 0
            }, completionHandler: { [weak self] in
                self?.orderOut(nil)
            })
        }
    }

    // MARK: - Private Methods

    /// Update the SwiftUI content view.
    private func updateContent() {
        guard let appState = appState else { return }

        let contentView = RecordingOverlayContentView(appState: appState)
            .frame(width: windowWidth, height: windowHeight)

        if let hostingView = hostingView {
            hostingView.rootView = AnyView(contentView)
        } else {
            let hosting = NSHostingView(rootView: AnyView(contentView))
            hosting.frame = NSRect(x: 0, y: 0, width: windowWidth, height: windowHeight)
            self.contentView = hosting
            self.hostingView = hosting
        }
    }
}

// MARK: - Content View

/// SwiftUI content view for the recording overlay.
private struct RecordingOverlayContentView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        ZStack {
            // Background with blur effect
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                .clipShape(RoundedRectangle(cornerRadius: 10))

            // Visualizer content
            AudioVisualizerView(audioLevel: appState.audioLevel)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
        }
    }
}

// MARK: - Visual Effect View

/// NSVisualEffectView wrapper for SwiftUI.
private struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

// MARK: - Preview

#if DEBUG
struct RecordingOverlayContentView_Previews: PreviewProvider {
    static var previews: some View {
        RecordingOverlayContentView(appState: AppState())
            .frame(width: 200, height: 50)
            .previewDisplayName("Overlay Content")
    }
}
#endif
