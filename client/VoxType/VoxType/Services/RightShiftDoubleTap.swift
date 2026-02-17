import Foundation

/// Fixed-window detector for double-tap input.
struct DoubleTapWindowDetector {
    let windowSeconds: TimeInterval
    private(set) var lastTapAt: TimeInterval?

    init(windowSeconds: TimeInterval) {
        self.windowSeconds = windowSeconds
    }

    mutating func registerTap(at now: TimeInterval) -> Bool {
        defer { lastTapAt = now }

        guard let lastTapAt else {
            return false
        }

        return now - lastTapAt <= windowSeconds
    }

    mutating func reset() {
        lastTapAt = nil
    }
}

/// Toggle helper for right-shift double-tap recording control.
struct RightShiftDoubleTapToggle {
    private(set) var detector: DoubleTapWindowDetector

    var onStart: (() -> Void)?
    var onStop: (() -> Void)?

    init(windowSeconds: TimeInterval) {
        self.detector = DoubleTapWindowDetector(windowSeconds: windowSeconds)
    }

    mutating func registerTap(at now: TimeInterval, isRecording: Bool, isAutoRepeat: Bool = false) -> Bool {
        guard !isAutoRepeat else { return false }

        let isDoubleTap = detector.registerTap(at: now)
        guard isDoubleTap else { return false }

        if isRecording {
            onStop?()
        } else {
            onStart?()
        }
        detector.reset()
        return true
    }

    mutating func resetSequence() {
        detector.reset()
    }
}
