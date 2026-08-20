import XCTest
@testable import HealthFirstApp

final class StandingGuideTimelineTests: XCTestCase {
    private let accuracy = 1e-9

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
            at: 8.3,
            activeBeat: .title,
            progress: [0.5, 0, 0, 0]
        )
        assertGuide(
            at: 8.6,
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
            8.6,
            21.999,
            22.6,
            37.999,
            38.6,
            51.999,
            52.6,
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
        XCTAssertEqual(initial.cardPickupProgress, 0, accuracy: accuracy)
        XCTAssertEqual(initial.cardPlacementProgress, 0, accuracy: accuracy)
        XCTAssertEqual(initial.trolleyCompressionProgress, 0, accuracy: accuracy)
        XCTAssertEqual(initial.smileProgress, 0, accuracy: accuracy)
        XCTAssertEqual(initial.settleProgress, 0, accuracy: accuracy)
        XCTAssertTrue(initial.isAnimating)

        let pickup = StandingCompletionTimeline.snapshot(elapsed: 0.16)
        XCTAssertEqual(pickup.cardPickupProgress, 1, accuracy: accuracy)
        XCTAssertEqual(pickup.cardPlacementProgress, 0, accuracy: accuracy)
        XCTAssertFalse(pickup.cardIsPlaced)

        let placement = StandingCompletionTimeline.snapshot(elapsed: 0.42)
        XCTAssertEqual(placement.cardPickupProgress, 1, accuracy: accuracy)
        XCTAssertEqual(placement.cardPlacementProgress, 1, accuracy: accuracy)
        XCTAssertTrue(placement.cardIsPlaced)

        let compressionPeak = StandingCompletionTimeline.snapshot(elapsed: 0.65)
        XCTAssertEqual(
            compressionPeak.trolleyCompressionProgress,
            1,
            accuracy: accuracy
        )

        let compressionEnd = StandingCompletionTimeline.snapshot(elapsed: 0.78)
        XCTAssertEqual(
            compressionEnd.trolleyCompressionProgress,
            0,
            accuracy: accuracy
        )

        let completed = StandingCompletionTimeline.snapshot(elapsed: 1.05)
        XCTAssertEqual(completed.cardPickupProgress, 1, accuracy: accuracy)
        XCTAssertEqual(completed.cardPlacementProgress, 1, accuracy: accuracy)
        XCTAssertEqual(completed.trolleyCompressionProgress, 0, accuracy: accuracy)
        XCTAssertEqual(completed.smileProgress, 1, accuracy: accuracy)
        XCTAssertEqual(completed.settleProgress, 1, accuracy: accuracy)
        XCTAssertFalse(completed.isAnimating)
    }

    func testCompletionCompressionHasOnePeakAndReturnsToZero() {
        let samples = (0...105).map { step in
            StandingCompletionTimeline.snapshot(
                elapsed: Double(step) / 100
            ).trolleyCompressionProgress
        }

        XCTAssertEqual(samples.first, 0)
        XCTAssertEqual(samples.last, 0)

        for index in 1...65 {
            XCTAssertGreaterThanOrEqual(
                samples[index] + accuracy,
                samples[index - 1],
                "compression regressed before peak at sample \(index)"
            )
        }
        for index in 66..<samples.count {
            XCTAssertLessThanOrEqual(
                samples[index],
                samples[index - 1] + accuracy,
                "compression rose after peak at sample \(index)"
            )
        }

        XCTAssertEqual(samples.max(), 1)
        XCTAssertEqual(
            samples.filter { abs($0 - 1) <= accuracy }.count,
            1,
            "compression should have exactly one sampled peak"
        )
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
}
