import XCTest
@testable import VoxType

final class AutoStop60sTests: XCTestCase {

    // MARK: - Auto-limit stop reason

    func testAutoStopUsesAutoLimitReasonAt60Seconds() {
        let policy = RecordingLimitPolicy(limit: 60.0)

        XCTAssertEqual(policy.stopReason(elapsed: 60.0), .autoLimit)
    }

    func testUnder60SecondsDoesNotAutoStop() {
        let policy = RecordingLimitPolicy(limit: 60.0)

        XCTAssertNil(policy.stopReason(elapsed: 59.9))
    }

    func testOver60SecondsAutoStops() {
        let policy = RecordingLimitPolicy(limit: 60.0)

        XCTAssertEqual(policy.stopReason(elapsed: 60.1), .autoLimit)
    }

    // MARK: - Single-shot stop flow

    func testAutoStopFlowRunsOnlyOnce() {
        var gate = RecordingStopGate()

        XCTAssertTrue(gate.approveStopFlow(isRecording: true))
        XCTAssertFalse(
            gate.approveStopFlow(isRecording: true),
            "自動停止の停止後フローは1回だけ実行される必要があります。"
        )
    }

    func testKeyUpAfterAutoStopDoesNotTriggerSecondProcessing() {
        var gate = RecordingStopGate()

        // Auto stop at 60s moves the app out of .recording.
        XCTAssertTrue(gate.approveStopFlow(isRecording: true))

        // A late key-up arrives while the app is already processing.
        XCTAssertFalse(
            gate.approveStopFlow(isRecording: false),
            "自動停止後の keyUp で二重処理が発生してはいけません。"
        )
    }

    func testDelayedMouseUpAfterAutoStopDoesNotTriggerSecondProcessing() {
        var gate = RecordingStopGate()

        XCTAssertTrue(gate.approveStopFlow(isRecording: true))

        // mouseWheelHold can deliver a delayed mouseUp before the status settles.
        XCTAssertFalse(
            gate.approveStopFlow(isRecording: true),
            "遅延 mouseUp でも停止後フローは再実行されてはいけません。"
        )
    }

    func testManualStopBeforeAutoLimitBlocksLaterAutoStop() {
        var gate = RecordingStopGate()

        XCTAssertTrue(gate.approveStopFlow(isRecording: true))
        XCTAssertFalse(gate.approveStopFlow(isRecording: false))
    }

    func testGateDoesNotApproveWhenNotRecording() {
        var gate = RecordingStopGate()

        XCTAssertFalse(gate.approveStopFlow(isRecording: false))
        XCTAssertFalse(gate.isInFlight)
    }

    func testResetAllowsNextRecordingToStop() {
        var gate = RecordingStopGate()

        XCTAssertTrue(gate.approveStopFlow(isRecording: true))
        gate.reset()

        XCTAssertFalse(gate.isInFlight)
        XCTAssertTrue(gate.approveStopFlow(isRecording: true))
    }
}
