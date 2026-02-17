import XCTest
@testable import VoxType

final class DoubleTapWindowDetectorTests: XCTestCase {
    func testSecondTapWithin399msIsSuccess() {
        var detector = DoubleTapWindowDetector(windowSeconds: 0.4)

        XCTAssertFalse(detector.registerTap(at: 0.0))
        XCTAssertTrue(detector.registerTap(at: 0.399))
    }

    func testSecondTapAt400msIsSuccess() {
        var detector = DoubleTapWindowDetector(windowSeconds: 0.4)

        XCTAssertFalse(detector.registerTap(at: 10.0))
        XCTAssertTrue(detector.registerTap(at: 10.4))
    }

    func testSecondTapAt401msIsFailure() {
        var detector = DoubleTapWindowDetector(windowSeconds: 0.4)

        XCTAssertFalse(detector.registerTap(at: 20.0))
        XCTAssertFalse(detector.registerTap(at: 20.401))
    }
}
