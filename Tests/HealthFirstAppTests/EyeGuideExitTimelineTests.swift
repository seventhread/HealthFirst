import XCTest
@testable import HealthFirstApp

final class EyeGuideExitTimelineTests: XCTestCase {
    func testLargeCardChromeClearsCompletely() {
        XCTAssertEqual(
            EyeGuideExitTimeline.cardChromeOpacity(
                at: EyeGuideExitTimeline.cardClearStart
            ),
            1
        )
        XCTAssertEqual(
            EyeGuideExitTimeline.cardChromeOpacity(
                at: EyeGuideExitTimeline.cardClearStart
                    + EyeGuideExitTimeline.cardClearDuration / 2
            ),
            0.5,
            accuracy: 0.0001
        )
        XCTAssertEqual(
            EyeGuideExitTimeline.cardChromeOpacity(
                at: EyeGuideExitTimeline.cardClearEnd
            ),
            0
        )
        XCTAssertEqual(
            EyeGuideExitTimeline.cardChromeOpacity(at: 20),
            0
        )
    }

    func testFullMascotIsHeldForFirstThreeSeconds() {
        XCTAssertEqual(EyeGuideExitTimeline.handoffProgress(at: 0), 0)
        XCTAssertEqual(EyeGuideExitTimeline.handoffProgress(at: 2.99), 0)
        XCTAssertEqual(EyeGuideExitTimeline.handoffProgress(at: 3.00), 0)
        XCTAssertEqual(
            EyeGuideExitTimeline.mascotOpacity(
                at: 3.00,
                reduceMotion: false
            ),
            1
        )
    }

    func testFoldSettlesIntoPersistentCompanion() {
        XCTAssertEqual(
            EyeGuideExitTimeline.handoffProgress(at: 3.55),
            0.5,
            accuracy: 0.0001
        )
        XCTAssertEqual(
            EyeGuideExitTimeline.handoffProgress(
                at: EyeGuideExitTimeline.handoffEnd
            ),
            1,
            accuracy: 0.0001
        )
        XCTAssertEqual(
            EyeGuideExitTimeline.companionProgress(
                at: EyeGuideExitTimeline.companionSettleStart,
                reduceMotion: false
            ),
            0
        )
        XCTAssertEqual(
            EyeGuideExitTimeline.companionProgress(
                at: EyeGuideExitTimeline.companionSettleStart + 0.5,
                reduceMotion: false
            ),
            0.5,
            accuracy: 0.0001
        )
        XCTAssertEqual(
            EyeGuideExitTimeline.companionProgress(
                at: EyeGuideExitTimeline.companionSettleEnd,
                reduceMotion: false
            ),
            1
        )
        XCTAssertEqual(
            EyeGuideExitTimeline.mascotOpacity(at: 10, reduceMotion: false),
            1
        )
        XCTAssertFalse(
            EyeGuideExitTimeline.isMascotTimelineActive(
                at: EyeGuideExitTimeline.companionSettleEnd,
                reduceMotion: false
            )
        )
    }

    func testDecorativeChromeClearsAsCompanionSettles() {
        XCTAssertEqual(
            EyeGuideExitTimeline.decorativeOpacity(
                at: EyeGuideExitTimeline.companionSettleStart
            ),
            1
        )
        XCTAssertEqual(
            EyeGuideExitTimeline.decorativeOpacity(
                at: EyeGuideExitTimeline.companionSettleStart
                    + EyeGuideExitTimeline.decorativeFadeDuration / 2
            ),
            0.5,
            accuracy: 0.0001
        )
        XCTAssertEqual(
            EyeGuideExitTimeline.decorativeOpacity(
                at: EyeGuideExitTimeline.decorativeFadeEnd
            ),
            0
        )
    }

    func testReduceMotionSwitchesDirectlyToSettledCompanion() {
        XCTAssertEqual(
            EyeGuideExitTimeline.companionProgress(
                at: EyeGuideExitTimeline.companionSettleStart - 0.01,
                reduceMotion: true
            ),
            0
        )
        XCTAssertEqual(
            EyeGuideExitTimeline.companionProgress(
                at: EyeGuideExitTimeline.companionSettleStart,
                reduceMotion: true
            ),
            1
        )
        XCTAssertEqual(
            EyeGuideExitTimeline.mascotOpacity(at: 20, reduceMotion: true),
            1
        )
        XCTAssertFalse(
            EyeGuideExitTimeline.isMascotTimelineActive(
                at: EyeGuideExitTimeline.companionSettleStart,
                reduceMotion: true
            )
        )
    }
}
