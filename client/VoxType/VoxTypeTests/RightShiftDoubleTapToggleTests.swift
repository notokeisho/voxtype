import XCTest
@testable import VoxType

final class RightShiftDoubleTapToggleTests: XCTestCase {
    func testDoubleTapStartsRecordingWhenIdle() {
        var toggle = RightShiftDoubleTapToggle(windowSeconds: 0.4)
        var didStart = false
        var didStop = false

        toggle.onStart = { didStart = true }
        toggle.onStop = { didStop = true }

        XCTAssertFalse(toggle.registerTap(at: 0.0, isRecording: false))
        XCTAssertTrue(toggle.registerTap(at: 0.2, isRecording: false))
        XCTAssertTrue(didStart)
        XCTAssertFalse(didStop)
    }

    func testDoubleTapStopsRecordingWhenRecording() {
        var toggle = RightShiftDoubleTapToggle(windowSeconds: 0.4)
        var didStart = false
        var didStop = false

        toggle.onStart = { didStart = true }
        toggle.onStop = { didStop = true }

        XCTAssertFalse(toggle.registerTap(at: 1.0, isRecording: true))
        XCTAssertTrue(toggle.registerTap(at: 1.3, isRecording: true))
        XCTAssertFalse(didStart)
        XCTAssertTrue(didStop)
    }

    func testAutoRepeatIsIgnored() {
        var toggle = RightShiftDoubleTapToggle(windowSeconds: 0.4)
        var didStart = false
        toggle.onStart = { didStart = true }

        XCTAssertFalse(toggle.registerTap(at: 0.0, isRecording: false))
        XCTAssertFalse(toggle.registerTap(at: 0.1, isRecording: false, isAutoRepeat: true))
        XCTAssertFalse(didStart)
    }

    func testOtherKeyResetsTapSequence() {
        var toggle = RightShiftDoubleTapToggle(windowSeconds: 0.4)
        var didStart = false
        toggle.onStart = { didStart = true }

        XCTAssertFalse(toggle.registerTap(at: 1.0, isRecording: false))
        toggle.resetSequence()
        XCTAssertFalse(toggle.registerTap(at: 1.2, isRecording: false))
        XCTAssertFalse(didStart)
    }
}
