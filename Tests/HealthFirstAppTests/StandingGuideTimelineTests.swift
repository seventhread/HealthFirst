import XCTest
@testable import HealthFirstApp

final class StandingGuideTimelineTests: XCTestCase {
    private let accuracy = 1e-9

    func testCompletionPropsUseVisibleStageContactPoints() {
        XCTAssertEqual(
            StandingStageGeometry.completionDockGrabPoint.x
                - StandingStageGeometry.completionDockCenter.x,
            111,
            accuracy: accuracy
        )
        XCTAssertEqual(
            StandingStageGeometry.completionDockGrabPoint.y,
            StandingStageGeometry.completionDockCenter.y,
            accuracy: accuracy
        )
        XCTAssertGreaterThan(
            StandingStageGeometry.completionBackdropGrabPoint.y,
            StandingStageGeometry.size.height - 20
        )
        XCTAssertLessThanOrEqual(
            StandingStageGeometry.completionBackdropGrabPoint.y,
            StandingStageGeometry.size.height
        )
    }

    func testCollectionTimingKeepsSourceUntilPlacementCrossfade() {
        XCTAssertEqual(StandingBeat.duration, 2.0, accuracy: accuracy)
        XCTAssertLessThan(
            StandingCollectionTiming.reachEnd,
            StandingCollectionTiming.gripEnd
        )
        XCTAssertLessThan(
            StandingCollectionTiming.gripEnd,
            StandingCollectionTiming.pullEnd
        )
        XCTAssertLessThan(
            StandingCollectionTiming.pullEnd,
            StandingCollectionTiming.placeEnd
        )
        XCTAssertLessThan(
            StandingCollectionTiming.placeEnd,
            StandingCollectionTiming.releaseEnd
        )
        XCTAssertLessThan(StandingCollectionTiming.releaseEnd, 1)

        for beat in StandingBeat.allCases {
            let atGrip = snapshot(
                beat,
                normalizedProgress: StandingCollectionTiming.gripEnd
            )
            XCTAssertEqual(
                atGrip.progress(for: beat),
                StandingCollectionTiming.gripEnd,
                accuracy: accuracy
            )
            XCTAssertEqual(atGrip.sourceOpacity(for: beat), 1, accuracy: accuracy)

            let atPullEnd = snapshot(
                beat,
                normalizedProgress: StandingCollectionTiming.pullEnd
            )
            XCTAssertEqual(atPullEnd.sourceOpacity(for: beat), 1, accuracy: accuracy)

            let placementMidpoint = (
                StandingCollectionTiming.pullEnd
                    + StandingCollectionTiming.placeEnd
            ) / 2
            let placing = snapshot(
                beat,
                normalizedProgress: placementMidpoint
            )
            XCTAssertEqual(placing.sourceOpacity(for: beat), 0.5, accuracy: accuracy)

            let placed = snapshot(
                beat,
                normalizedProgress: StandingCollectionTiming.placeEnd
            )
            XCTAssertEqual(placed.sourceOpacity(for: beat), 0, accuracy: accuracy)
            XCTAssertEqual(placed.placementProgress(for: beat), 1, accuracy: accuracy)
        }
    }

    func testStandingSourcesUseDeliberateNestedInsets() {
        let dockLeading = StandingStageGeometry.completionDockCenter.x - 111
        let railsHalfWidth = StandingStageGeometry.railsSourceSize.width / 2
        let backingHalfWidth = StandingStageGeometry.backingSourceSize.width / 2
        let railsLeading = StandingStageGeometry.railsSourceCenter.x - railsHalfWidth
        let backingLeading = StandingStageGeometry.backingSourceCenter.x - backingHalfWidth
        let titleLeading = StandingStageGeometry.titleSourceCenter.x - 59

        XCTAssertEqual(railsLeading, dockLeading + 8, accuracy: accuracy)
        XCTAssertEqual(backingLeading, railsLeading + 8, accuracy: accuracy)
        XCTAssertEqual(titleLeading, railsLeading + 16, accuracy: accuracy)
        XCTAssertEqual(
            StandingStageGeometry.railsSourceCenter.y
                - StandingStageGeometry.railsSourceSize.height / 2,
            51,
            accuracy: accuracy
        )
        XCTAssertEqual(
            StandingCollectionGeometry.sourceGrabPoint(for: .rails).x,
            StandingStageGeometry.railsSourceCenter.x + railsHalfWidth - 1,
            accuracy: accuracy
        )
        XCTAssertEqual(
            StandingCollectionGeometry.sourceGrabPoint(for: .backing).x,
            StandingStageGeometry.backingSourceCenter.x + backingHalfWidth,
            accuracy: accuracy
        )

        let railsTrailing = StandingStageGeometry.railsSourceCenter.x
            + railsHalfWidth
        // The trolley cargo begins 6 pt inside its 74 pt stage frame.
        let trolleyCargoLeading = StandingStageGeometry.trolleyCenter.x
            - StandingStageGeometry.trolleySize.width / 2 + 6
        XCTAssertEqual(
            trolleyCargoLeading - railsTrailing,
            8,
            accuracy: accuracy
        )
    }

    func testFirstCollectedPartBecomesDetachedTrolleyBase() {
        let destination = StandingCollectionGeometry.destinationGrabPoint(for: .title)

        XCTAssertEqual(StandingStageGeometry.baseDestinationCenter.x, 251, accuracy: accuracy)
        XCTAssertEqual(StandingStageGeometry.baseDestinationCenter.y, 159, accuracy: accuracy)
        XCTAssertEqual(destination.x, 273, accuracy: accuracy)
        XCTAssertEqual(destination.y, 159, accuracy: accuracy)
        XCTAssertEqual(
            StandingStageGeometry.baseDestinationCenter.x + 22,
            destination.x,
            accuracy: accuracy
        )
        XCTAssertGreaterThan(StandingCollectionGeometry.home.x, destination.x)
        XCTAssertGreaterThan(StandingCollectionGeometry.home.y, destination.y)
    }

    func testGuideSnapshotsAtStoryboardTimes() {
        assertGuide(
            at: 0,
            activeBeat: nil,
            progress: [0, 0, 0, 0]
        )
        assertGuide(
            at: 8,
            activeBeat: .title,
            progress: [0, 0, 0, 0]
        )
        assertGuide(
            at: StandingBeat.title.startSeconds + StandingBeat.duration / 2,
            activeBeat: .title,
            progress: [0.5, 0, 0, 0]
        )
        assertGuide(
            at: StandingBeat.title.endSeconds,
            activeBeat: nil,
            progress: [1, 0, 0, 0]
        )
        assertGuide(
            at: 22,
            activeBeat: .backing,
            progress: [1, 0, 0, 0]
        )
        assertGuide(
            at: 38,
            activeBeat: .rails,
            progress: [1, 1, 0, 0]
        )
        assertGuide(
            at: 52,
            activeBeat: .ribbon,
            progress: [1, 1, 1, 0]
        )
        assertGuide(
            at: 60,
            activeBeat: nil,
            progress: [1, 1, 1, 1]
        )
    }

    func testGuideElapsedTimeClampsInvalidAndOutOfRangeInputs() {
        let nan = StandingGuideTimeline.snapshot(elapsed: .nan)
        XCTAssertEqual(nan.elapsed, 0, accuracy: accuracy)
        XCTAssertEqual(nan.assembly, .empty)
        XCTAssertNil(nan.activeBeat)

        let negative = StandingGuideTimeline.snapshot(elapsed: -12)
        XCTAssertEqual(negative.elapsed, 0, accuracy: accuracy)
        XCTAssertEqual(negative.assembly, .empty)
        XCTAssertNil(negative.activeBeat)

        let overtime = StandingGuideTimeline.snapshot(elapsed: 600)
        XCTAssertEqual(
            overtime.elapsed,
            StandingGuideTimeline.duration,
            accuracy: accuracy
        )
        XCTAssertEqual(overtime.assembly, .completed)
        XCTAssertNil(overtime.activeBeat)
    }

    func testEveryAssemblyPartProgressesMonotonically() {
        var previous = StandingAssembly.empty

        for elapsed in stride(from: 0.0, through: 60.0, by: 0.05) {
            let current = StandingGuideTimeline.snapshot(elapsed: elapsed).assembly

            for beat in StandingBeat.allCases {
                let oldValue = previous.progress(for: beat)
                let newValue = current.progress(for: beat)
                XCTAssertGreaterThanOrEqual(
                    newValue + accuracy,
                    oldValue,
                    "\(beat.rawValue) regressed at \(elapsed)s"
                )
                XCTAssertGreaterThanOrEqual(newValue, 0)
                XCTAssertLessThanOrEqual(newValue, 1)
            }

            previous = current
        }
    }

    func testActiveBeatUsesHalfOpenAnimationWindows() {
        for beat in StandingBeat.allCases {
            XCTAssertEqual(
                StandingGuideTimeline.snapshot(elapsed: beat.startSeconds).activeBeat,
                beat
            )
            XCTAssertEqual(
                StandingGuideTimeline.snapshot(
                    elapsed: beat.startSeconds + StandingBeat.duration / 2
                ).activeBeat,
                beat
            )
            XCTAssertEqual(
                StandingGuideTimeline.snapshot(elapsed: beat.endSeconds - 0.001).activeBeat,
                beat
            )
            XCTAssertNil(
                StandingGuideTimeline.snapshot(elapsed: beat.endSeconds).activeBeat
            )
        }

        let outsideWindows: [TimeInterval] = [
            0,
            7.999,
            StandingBeat.title.endSeconds,
            21.999,
            StandingBeat.backing.endSeconds,
            37.999,
            StandingBeat.rails.endSeconds,
            51.999,
            StandingBeat.ribbon.endSeconds,
            60
        ]
        for elapsed in outsideWindows {
            XCTAssertNil(
                StandingGuideTimeline.snapshot(elapsed: elapsed).activeBeat,
                "unexpected beat at \(elapsed)s"
            )
            XCTAssertFalse(StandingGuideTimeline.isAnimating(at: elapsed))
        }
    }

    func testCompletionSnapshotsAtChoreographyBoundaries() {
        let initial = StandingCompletionTimeline.snapshot(elapsed: 0)
        XCTAssertEqual(initial.activeBeat, .dock)
        assertPack(initial.dock, [0, 0, 0, 0, 0])
        assertPack(initial.backdrop, [0, 0, 0, 0, 0])
        XCTAssertEqual(initial.trolleyCompressionProgress, 0, accuracy: accuracy)
        XCTAssertEqual(initial.smileProgress, 0, accuracy: accuracy)
        XCTAssertEqual(initial.receiptRevealProgress, 0, accuracy: accuracy)
        XCTAssertTrue(initial.isAnimating)

        let dockReached = StandingCompletionTimeline.snapshot(elapsed: 0.28)
        assertPack(dockReached.dock, [1, 0, 0, 0, 0])
        assertPack(dockReached.backdrop, [0, 0, 0, 0, 0])

        let dockGrabbed = StandingCompletionTimeline.snapshot(elapsed: 0.42)
        assertPack(dockGrabbed.dock, [1, 1, 0, 0, 0])
        assertPack(dockGrabbed.backdrop, [0, 0, 0, 0, 0])

        let dockPlaced = StandingCompletionTimeline.snapshot(elapsed: 1.12)
        assertPack(dockPlaced.dock, [1, 1, 1, 1, 0])
        assertPack(dockPlaced.backdrop, [0, 0, 0, 0, 0])
        XCTAssertTrue(dockPlaced.dock.isPlaced)

        let firstCompressionPeak = StandingCompletionTimeline.snapshot(elapsed: 1.27)
        XCTAssertEqual(
            firstCompressionPeak.trolleyCompressionProgress,
            1,
            accuracy: accuracy
        )

        let pause = StandingCompletionTimeline.snapshot(elapsed: 1.37)
        XCTAssertNil(pause.activeBeat)
        assertPack(pause.dock, [1, 1, 1, 1, 1])
        assertPack(pause.backdrop, [0, 0, 0, 0, 0])

        let backdropReached = StandingCompletionTimeline.snapshot(elapsed: 1.72)
        XCTAssertEqual(backdropReached.activeBeat, .backdrop)
        assertPack(backdropReached.backdrop, [1, 0, 0, 0, 0])

        let backdropGrabbed = StandingCompletionTimeline.snapshot(elapsed: 1.86)
        assertPack(backdropGrabbed.backdrop, [1, 1, 0, 0, 0])

        let backdropPlaced = StandingCompletionTimeline.snapshot(elapsed: 2.78)
        assertPack(backdropPlaced.backdrop, [1, 1, 1, 1, 0])
        XCTAssertTrue(backdropPlaced.backdrop.isPlaced)

        let secondCompressionPeak = StandingCompletionTimeline.snapshot(elapsed: 2.93)
        XCTAssertEqual(
            secondCompressionPeak.trolleyCompressionProgress,
            1,
            accuracy: accuracy
        )

        let completed = StandingCompletionTimeline.snapshot(
            elapsed: StandingCompletionTimeline.duration
        )
        XCTAssertNil(completed.activeBeat)
        assertPack(completed.dock, [1, 1, 1, 1, 1])
        assertPack(completed.backdrop, [1, 1, 1, 1, 1])
        XCTAssertEqual(completed.trolleyCompressionProgress, 0, accuracy: accuracy)
        XCTAssertEqual(completed.smileProgress, 1, accuracy: accuracy)
        XCTAssertEqual(completed.receiptRevealProgress, 1, accuracy: accuracy)
        XCTAssertTrue(completed.isReadyForReceipt)
        XCTAssertFalse(completed.isAnimating)
    }

    func testCompletionPackOrderNeverOverlaps() {
        var previousDock = StandingCompletionTimeline.snapshot(elapsed: 0).dock
        var previousBackdrop = StandingCompletionTimeline.snapshot(elapsed: 0).backdrop

        for elapsed in stride(
            from: 0.0,
            through: StandingCompletionTimeline.duration,
            by: 0.01
        ) {
            let snapshot = StandingCompletionTimeline.snapshot(elapsed: elapsed)

            if snapshot.backdrop.reachProgress > 0 {
                XCTAssertTrue(
                    snapshot.dock.isPlaced,
                    "backdrop began before dock placement at \(elapsed)s"
                )
                XCTAssertEqual(snapshot.dock.releaseProgress, 1, accuracy: accuracy)
            }
            if snapshot.receiptRevealProgress > 0 {
                XCTAssertTrue(snapshot.backdrop.isPlaced)
                XCTAssertEqual(snapshot.backdrop.releaseProgress, 1, accuracy: accuracy)
            }

            assertPackMonotonic(previous: previousDock, current: snapshot.dock)
            assertPackMonotonic(previous: previousBackdrop, current: snapshot.backdrop)
            previousDock = snapshot.dock
            previousBackdrop = snapshot.backdrop
        }
    }

    func testCompletionCompressionHasTwoSeparatedPeaksAndReturnsToZero() {
        let firstPeak = StandingCompletionTimeline.snapshot(elapsed: 1.27)
        let between = StandingCompletionTimeline.snapshot(elapsed: 1.42)
        let secondPeak = StandingCompletionTimeline.snapshot(elapsed: 2.93)
        let completed = StandingCompletionTimeline.snapshot(
            elapsed: StandingCompletionTimeline.duration
        )

        XCTAssertEqual(firstPeak.trolleyCompressionProgress, 1, accuracy: accuracy)
        XCTAssertEqual(between.trolleyCompressionProgress, 0, accuracy: accuracy)
        XCTAssertEqual(secondPeak.trolleyCompressionProgress, 1, accuracy: accuracy)
        XCTAssertEqual(completed.trolleyCompressionProgress, 0, accuracy: accuracy)
    }

    func testCompletionElapsedClampsInvalidAndOutOfRangeInputs() {
        let nan = StandingCompletionTimeline.snapshot(elapsed: .nan)
        XCTAssertEqual(nan, .initial)

        let negative = StandingCompletionTimeline.snapshot(elapsed: -4)
        XCTAssertEqual(negative, .initial)

        let overtime = StandingCompletionTimeline.snapshot(elapsed: 400)
        XCTAssertEqual(overtime, .completed)
        XCTAssertFalse(overtime.isAnimating)
        XCTAssertTrue(overtime.isReadyForReceipt)
    }

    private func assertPack(
        _ pack: StandingPackProgress,
        _ expected: [Double],
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let actual = [
            pack.reachProgress,
            pack.gripProgress,
            pack.transferProgress,
            pack.placementProgress,
            pack.releaseProgress,
        ]
        XCTAssertEqual(actual.count, expected.count, file: file, line: line)
        for (actualValue, expectedValue) in zip(actual, expected) {
            XCTAssertEqual(
                actualValue,
                expectedValue,
                accuracy: accuracy,
                file: file,
                line: line
            )
        }
    }

    private func assertPackMonotonic(
        previous: StandingPackProgress,
        current: StandingPackProgress,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let oldValues = [
            previous.reachProgress,
            previous.gripProgress,
            previous.transferProgress,
            previous.placementProgress,
            previous.releaseProgress,
        ]
        let newValues = [
            current.reachProgress,
            current.gripProgress,
            current.transferProgress,
            current.placementProgress,
            current.releaseProgress,
        ]
        for (oldValue, newValue) in zip(oldValues, newValues) {
            XCTAssertGreaterThanOrEqual(
                newValue + accuracy,
                oldValue,
                file: file,
                line: line
            )
        }
    }

    private func assertGuide(
        at elapsed: TimeInterval,
        activeBeat: StandingBeat?,
        progress: [Double],
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let snapshot = StandingGuideTimeline.snapshot(elapsed: elapsed)
        XCTAssertEqual(snapshot.activeBeat, activeBeat, file: file, line: line)

        let actual = StandingBeat.allCases.map(snapshot.progress(for:))
        XCTAssertEqual(actual.count, progress.count, file: file, line: line)
        for (actualValue, expectedValue) in zip(actual, progress) {
            XCTAssertEqual(
                actualValue,
                expectedValue,
                accuracy: accuracy,
                file: file,
                line: line
            )
        }
    }

    private func snapshot(
        _ beat: StandingBeat,
        normalizedProgress: Double
    ) -> StandingGuideSnapshot {
        StandingGuideTimeline.snapshot(
            elapsed: beat.startSeconds
                + normalizedProgress * StandingBeat.duration
        )
    }
}
