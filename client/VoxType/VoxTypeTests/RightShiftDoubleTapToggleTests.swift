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
}
