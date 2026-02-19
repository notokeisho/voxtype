import XCTest
@testable import VoxType

final class AutoStop60sFailingTests: XCTestCase {
    func testAutoStopUsesAutoLimitReasonAt60Seconds() {
        XCTFail("未実装: 60秒到達時に RecordingStopReason.autoLimit が通知されることを確認する")
    }

    func testAutoStopFlowRunsOnlyOnce() {
        XCTFail("未実装: 自動停止時に停止後フローが1回だけ実行されることを確認する")
    }

    func testKeyUpAfterAutoStopDoesNotTriggerSecondProcessing() {
        XCTFail("未実装: 自動停止後の keyUp で二重処理が発生しないことを確認する")
    }
}
