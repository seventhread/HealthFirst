import XCTest
@testable import HealthFirstCore

final class ReminderStateMachineTests: XCTestCase {
    private let origin = Date(timeIntervalSinceReferenceDate: 1_000_000)

    func testDefaultConfiguration() {
        let configuration = HealthFirstConfiguration.default

        XCTAssertEqual(
            configuration.policy(for: .eye),
            ReminderPolicy(
                isEnabled: true,
                cadence: .interval(seconds: 20 * 60)
            )
        )
        XCTAssertEqual(
            configuration.policy(for: .standing),
            ReminderPolicy(
                isEnabled: true,
                cadence: .interval(seconds: 40 * 60)
            )
        )
        XCTAssertEqual(
            configuration.policy(for: .quietPractice),
            ReminderPolicy(
                isEnabled: false,
                cadence: .dailyOccurrences(count: 3)
            )
        )
        XCTAssertEqual(configuration.retryDelay, 3 * 60)
        XCTAssertEqual(configuration.mode, .standard)
        XCTAssertEqual(ReminderKind.eye.guideDuration, 20)
        XCTAssertEqual(ReminderKind.standing.guideDuration, 60)
        XCTAssertEqual(ReminderKind.quietPractice.guideDuration, 30)
    }

    func testScheduledReminderPresentsOnlyWhenDue() throws {
        let dueAt = origin.addingTimeInterval(60)
        var reminder = ReminderInstance(kind: .eye, dueAt: dueAt)

        XCTAssertThrowsError(
            try reminder.send(.deadlineReached, at: origin)
        ) { error in
            XCTAssertEqual(
                error as? ReminderTransitionError,
                .deadlineNotReached(required: dueAt, received: self.origin)
            )
        }
        XCTAssertEqual(reminder.state, .scheduled(dueAt: dueAt))

        XCTAssertEqual(
            try reminder.send(.deadlineReached, at: dueAt),
            .firstPresented(at: dueAt)
        )
    }

    func testFirstNoResponseSchedulesFollowUpExactlyThreeMinutesLater() throws {
        var reminder = ReminderInstance(kind: .eye, dueAt: origin)
        try reminder.handle(.deadlineReached, at: origin)

        let ignoredAt = origin.addingTimeInterval(8)
        let retryAt = ignoredAt.addingTimeInterval(3 * 60)
        XCTAssertEqual(
            try reminder.handle(.noResponse, at: ignoredAt),
            .retryPending(retryAt: retryAt)
        )

        XCTAssertThrowsError(
            try reminder.handle(
                .deadlineReached,
                at: retryAt.addingTimeInterval(-0.001)
            )
        )
        XCTAssertEqual(
            try reminder.handle(.deadlineReached, at: retryAt),
            .followUpPresented(at: retryAt)
        )
    }

    func testSecondNoResponseReturnsStandardReminderToMenuBar() throws {
        var reminder = try followUpReminder(mode: .standard)
        let ignoredAt = origin.addingTimeInterval(200)

        XCTAssertEqual(
            try reminder.handle(.noResponse, at: ignoredAt),
            .pendingInMenuBar(since: ignoredAt)
        )
        XCTAssertNil(reminder.state.nextDeadline)
        XCTAssertFalse(reminder.state.isTerminal)
    }

    func testStartingEachKindUsesItsOwnGuideDuration() throws {
        for kind in ReminderKind.allCases {
            var reminder = ReminderInstance(kind: kind, dueAt: origin)
            try reminder.handle(.deadlineReached, at: origin)

            XCTAssertEqual(
                try reminder.handle(.start, at: origin),
                .guided(
                    startedAt: origin,
                    endsAt: origin.addingTimeInterval(kind.guideDuration)
                )
            )
        }
    }

    func testConfiguredGuideDurationIsSnapshottedByTheReminder() throws {
        var reminder = ReminderInstance(
            kind: .eye,
            dueAt: origin,
            guideDuration: 45
        )

        XCTAssertEqual(reminder.guideDuration, 45)
        try reminder.handle(.deadlineReached, at: origin)
        XCTAssertEqual(
            try reminder.handle(.start, at: origin),
            .guided(
                startedAt: origin,
                endsAt: origin.addingTimeInterval(45)
            )
        )
    }

    func testInvalidConfiguredGuideDurationFallsBackToKindDefault() {
        let invalidDurations: [TimeInterval] = [
            0,
            -1,
            .infinity,
            -.infinity,
            .nan
        ]
        for invalidDuration in invalidDurations {
            let reminder = ReminderInstance(
                kind: .standing,
                dueAt: origin,
                guideDuration: invalidDuration
            )
            XCTAssertEqual(reminder.guideDuration, 60)
        }
    }

    func testDecodingLegacyReminderWithoutGuideDurationUsesDefault() throws {
        let original = ReminderInstance(kind: .quietPractice, dueAt: origin)
        let encoded = try JSONEncoder().encode(original)
        var legacyObject = try XCTUnwrap(
            JSONSerialization.jsonObject(with: encoded) as? [String: Any]
        )
        legacyObject.removeValue(forKey: "guideDuration")
        let legacyData = try JSONSerialization.data(withJSONObject: legacyObject)

        let decoded = try JSONDecoder().decode(
            ReminderInstance.self,
            from: legacyData
        )

        XCTAssertEqual(decoded.guideDuration, ReminderKind.quietPractice.guideDuration)
        XCTAssertEqual(decoded.state, original.state)
    }

    func testCountdownCannotCompleteEarlyAndCompletesAtDeadline() throws {
        var reminder = ReminderInstance(kind: .eye, dueAt: origin)
        try reminder.handle(.deadlineReached, at: origin)
        try reminder.handle(.start, at: origin)

        let endsAt = origin.addingTimeInterval(20)
        let tooEarly = endsAt.addingTimeInterval(-1)
        XCTAssertThrowsError(
            try reminder.handle(.countdownCompleted, at: tooEarly)
        ) { error in
            XCTAssertEqual(
                error as? ReminderTransitionError,
                .countdownNotFinished(required: endsAt, received: tooEarly)
            )
        }
        XCTAssertEqual(
            try reminder.handle(.countdownCompleted, at: endsAt),
            .completed(at: endsAt)
        )
        XCTAssertTrue(reminder.state.isTerminal)
    }

    func testSnoozePreservesPresentationStage() throws {
        var first = ReminderInstance(kind: .standing, dueAt: origin)
        try first.handle(.deadlineReached, at: origin)

        let firstWake = origin.addingTimeInterval(180)
        XCTAssertEqual(
            try first.handle(.snooze(for: 180), at: origin),
            .snoozed(until: firstWake, resume: .first)
        )
        XCTAssertEqual(
            try first.handle(.deadlineReached, at: firstWake),
            .firstPresented(at: firstWake)
        )

        var followUp = try followUpReminder(mode: .standard)
        let snoozedAt = origin.addingTimeInterval(200)
        let followUpWake = snoozedAt.addingTimeInterval(600)
        XCTAssertEqual(
            try followUp.handle(.snooze(for: 600), at: snoozedAt),
            .snoozed(until: followUpWake, resume: .followUp)
        )
        XCTAssertEqual(
            try followUp.handle(.deadlineReached, at: followUpWake),
            .followUpPresented(at: followUpWake)
        )
    }

    func testInvalidSnoozeDoesNotMutateState() throws {
        var reminder = ReminderInstance(kind: .eye, dueAt: origin)
        try reminder.handle(.deadlineReached, at: origin)
        let previousState = reminder.state

        XCTAssertThrowsError(try reminder.handle(.snooze(for: 0), at: origin)) {
            error in
            XCTAssertEqual(
                error as? ReminderTransitionError,
                .invalidSnoozeDuration(0)
            )
        }
        XCTAssertEqual(reminder.state, previousState)
    }

    func testSkipAndEarlyEndAreRecordedAsSkipped() throws {
        var followUp = try followUpReminder(mode: .standard)
        let skippedAt = origin.addingTimeInterval(200)
        XCTAssertEqual(
            try followUp.handle(.skip, at: skippedAt),
            .skipped(at: skippedAt)
        )

        var guided = ReminderInstance(kind: .standing, dueAt: origin)
        try guided.handle(.deadlineReached, at: origin)
        try guided.handle(.start, at: origin)
        let endedAt = origin.addingTimeInterval(12)
        XCTAssertEqual(
            try guided.handle(.earlyEnd, at: endedAt),
            .skipped(at: endedAt)
        )
    }

    func testPendingMenuBarReminderCanBeStarted() throws {
        var reminder = try followUpReminder(mode: .standard)
        let pendingAt = origin.addingTimeInterval(200)
        try reminder.handle(.noResponse, at: pendingAt)

        let startedAt = pendingAt.addingTimeInterval(30)
        XCTAssertEqual(
            try reminder.handle(.start, at: startedAt),
            .guided(
                startedAt: startedAt,
                endsAt: startedAt.addingTimeInterval(20)
            )
        )
    }

    func testSeriousModeAddsOverlayAndSupportsEmergencySkip() throws {
        var reminder = try followUpReminder(mode: .serious)
        let overlayAt = origin.addingTimeInterval(200)
        XCTAssertEqual(
            try reminder.handle(.noResponse, at: overlayAt),
            .seriousPresented(at: overlayAt)
        )

        let skippedAt = overlayAt.addingTimeInterval(1)
        XCTAssertEqual(
            try reminder.handle(.emergencySkip, at: skippedAt),
            .emergencySkip(at: skippedAt)
        )
    }

    func testSeriousOverlayNoResponseReturnsToMenuBar() throws {
        var reminder = try followUpReminder(mode: .serious)
        let overlayAt = origin.addingTimeInterval(200)
        try reminder.handle(.noResponse, at: overlayAt)

        let ignoredAt = overlayAt.addingTimeInterval(15)
        XCTAssertEqual(
            try reminder.handle(.noResponse, at: ignoredAt),
            .pendingInMenuBar(since: ignoredAt)
        )
    }

    func testGlobalPauseDelaysRetryAndGuidanceDeadlines() throws {
        var retrying = ReminderInstance(kind: .eye, dueAt: origin)
        try retrying.send(.deadlineReached, at: origin)
        try retrying.send(.noResponse, at: origin)
        let originalRetryAt = origin.addingTimeInterval(3 * 60)

        XCTAssertEqual(
            try retrying.send(.delay(by: 75), at: origin.addingTimeInterval(10)),
            .retryPending(retryAt: originalRetryAt.addingTimeInterval(75))
        )

        var guided = ReminderInstance(kind: .standing, dueAt: origin)
        try guided.send(.deadlineReached, at: origin)
        try guided.send(.start, at: origin)

        XCTAssertEqual(
            try guided.send(.delay(by: 30), at: origin.addingTimeInterval(10)),
            .guided(
                startedAt: origin.addingTimeInterval(30),
                endsAt: origin.addingTimeInterval(90)
            )
        )
    }

    func testInvalidGlobalPauseDoesNotMutateReminder() throws {
        var reminder = ReminderInstance(kind: .eye, dueAt: origin)
        let previousState = reminder.state

        XCTAssertThrowsError(
            try reminder.send(.delay(by: -.infinity), at: origin)
        ) { error in
            XCTAssertEqual(
                error as? ReminderTransitionError,
                .invalidDelayDuration(-.infinity)
            )
        }
        XCTAssertEqual(reminder.state, previousState)
    }

    func testWallClockAdjustmentSupportsBothDirectionsAndTerminalStates() throws {
        var guided = ReminderInstance(kind: .eye, dueAt: origin)
        try guided.send(.deadlineReached, at: origin)
        try guided.send(.start, at: origin)

        XCTAssertEqual(
            try guided.send(
                .wallClockAdjusted(by: 3_600),
                at: origin.addingTimeInterval(1)
            ),
            .guided(
                startedAt: origin.addingTimeInterval(3_600),
                endsAt: origin.addingTimeInterval(3_620)
            )
        )
        XCTAssertEqual(
            try guided.send(
                .wallClockAdjusted(by: -1_800),
                at: origin.addingTimeInterval(2)
            ),
            .guided(
                startedAt: origin.addingTimeInterval(1_800),
                endsAt: origin.addingTimeInterval(1_820)
            )
        )

        var completed = ReminderInstance(kind: .eye, dueAt: origin)
        try completed.send(.deadlineReached, at: origin)
        try completed.send(.start, at: origin)
        try completed.send(.countdownCompleted, at: origin.addingTimeInterval(20))
        XCTAssertEqual(
            try completed.send(
                .wallClockAdjusted(by: -300),
                at: origin.addingTimeInterval(21)
            ),
            .completed(at: origin.addingTimeInterval(-280))
        )
    }

    private func followUpReminder(
        mode: ReminderMode
    ) throws -> ReminderInstance {
        var reminder = ReminderInstance(
            kind: .eye,
            dueAt: origin,
            mode: mode
        )
        try reminder.handle(.deadlineReached, at: origin)
        let noResponseAt = origin.addingTimeInterval(8)
        try reminder.handle(.noResponse, at: noResponseAt)
        let retryAt = noResponseAt.addingTimeInterval(3 * 60)
        try reminder.handle(.deadlineReached, at: retryAt)
        return reminder
    }
}
