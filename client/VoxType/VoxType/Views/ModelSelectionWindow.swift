import SwiftUI
import AppKit

@MainActor
final class ModelSelectionState: ObservableObject {
    @Published var selection: WhisperModel

    init(selection: WhisperModel) {
        self.selection = selection
    }
}

final class ModelSelectionWindow: NSPanel {
    static let shared = ModelSelectionWindow()

    private let settings = AppSettings.shared
    private let localization = LocalizationManager.shared
    private let state = ModelSelectionState(selection: .fast)
    private let windowWidth: CGFloat = 235
    private let windowHeight: CGFloat = 130

    private var onClose: (() -> Void)?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    private init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 280, height: 160),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        isOpaque = false
        backgroundColor = .clear
        isMovableByWindowBackground = false
        isReleasedWhenClosed = false
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .stationary]

        let view = ModelSelectionContentView(state: state, localization: localization)
        let hosting = NSHostingView(rootView: view)
        contentView = hosting
    }

    func show(onClose: @escaping () -> Void) {
        self.onClose = onClose
        state.selection = settings.whisperModel

        if let screen = NSScreen.main {
            let frame = screen.visibleFrame
            let originX = frame.midX - (windowWidth / 2)
            let originY = frame.maxY - windowHeight - 40
            setFrameOrigin(NSPoint(x: originX, y: originY))
        }

        makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func closePopup() {
        orderOut(nil)
        onClose?()
        onClose = nil
    }

    override func close() {
        closePopup()
    }

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 126: // Up arrow
            moveSelection(delta: -1)
        case 125: // Down arrow
            moveSelection(delta: 1)
        case 36, 76: // Enter, Keypad Enter
            settings.whisperModel = state.selection
            closePopup()
        case 53: // Escape
            closePopup()
        default:
            super.keyDown(with: event)
        }
    }

    private func moveSelection(delta: Int) {
        let models = WhisperModel.allCases
        guard let currentIndex = models.firstIndex(of: state.selection) else { return }
        let nextIndex = (currentIndex + delta + models.count) % models.count
        state.selection = models[nextIndex]
    }
}

private struct ModelSelectionContentView: View {
    @ObservedObject var state: ModelSelectionState
    let localization: LocalizationManager

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(red: 0.15, green: 0.15, blue: 0.17).opacity(0.95))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color(red: 0.95, green: 0.6, blue: 0.3), lineWidth: 1.5)
                )

            VStack(spacing: 10) {
                Text(localization.t("modelPopup.title"))
                    .font(.headline)
                    .foregroundColor(Color(red: 0.95, green: 0.6, blue: 0.3))

                VStack(alignment: .leading, spacing: 4) {
                    ForEach(WhisperModel.allCases, id: \.self) { model in
                        HStack(spacing: 6) {
                            Text(state.selection == model ? "●" : "○")
                                .foregroundColor(Color(red: 0.95, green: 0.6, blue: 0.3))
                            Text(model.displayName)
                                .foregroundColor(.white)
                        }
                        .font(.system(size: 13, weight: .medium))
                    }
                }

                Text(localization.t("modelPopup.hint"))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color(red: 0.85, green: 0.85, blue: 0.9))
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
