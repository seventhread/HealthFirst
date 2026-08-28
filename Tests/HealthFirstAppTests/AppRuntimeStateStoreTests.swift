import Foundation
import HealthFirstCore
import XCTest
@testable import HealthFirstApp

final class AppRuntimeStateStoreTests: XCTestCase {
    func testSnapshotRoundTripsAllBusinessState() throws {
        let suiteName = "HealthFirstAppTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let origin = Date(timeIntervalSince1970: 1_800_000_000)
        var active = ReminderInstance(
            kind: .eye,
            dueAt: origin,
            guideDuration: 30
        )
        try active.send(.deadlineReached, at: origin)
        try active.send(.snooze(for: 180), at: origin)

        var pending = ReminderInstance(kind: .standing, dueAt: origin)
        try pending.send(.deadlineReached, at: origin)
        try pending.send(.noResponse, at: origin)
        try pending.send(.deadlineReached, at: origin.addingTimeInterval(180))
        try pending.send(.noResponse, at: origin.addingTimeInterval(180))

        let snapshot = AppRuntimeSnapshot(
            savedAt: origin,
            nextDue: [
                .eye: origin.addingTimeInterval(1_200),
                .standing: origin.addingTimeInterval(2_400),
            ],
            deferredIntervalRemaining: [
                .eye: 1_200,
                .standing: 2_400,
            ],
            activeReminder: active,
            activeIsManual: false,
            pendingReminders: [pending],
            pausedUntil: origin.addingTimeInterval(3_600),
            pauseStartedAt: origin.addingTimeInterval(-120)
        )
        let store = AppRuntimeStateStore(defaults: defaults)

        try store.save(snapshot)

        XCTAssertEqual(store.load(), snapshot)
        XCTAssertTrue(
            snapshot.representsSameBusinessState(
                as: AppRuntimeSnapshot(
                    savedAt: origin.addingTimeInterval(10),
                    nextDue: snapshot.nextDue,
                    deferredIntervalRemaining:
                        snapshot.deferredIntervalRemaining,
                    activeReminder: snapshot.activeReminder,
                    activeIsManual: snapshot.activeIsManual,
                    pendingReminders: snapshot.pendingReminders,
                    pausedUntil: snapshot.pausedUntil,
                    pauseStartedAt: snapshot.pauseStartedAt
                )
            )
        )
    }

    func testCorruptSnapshotFailsClosedAndCanBeCleared() throws {
        let suiteName = "HealthFirstAppTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = AppRuntimeStateStore(defaults: defaults)

        defaults.set(Data("not-json".utf8), forKey: AppRuntimeStateStore.storageKey)
        XCTAssertNil(store.load())

        store.clear()
        XCTAssertNil(defaults.object(forKey: AppRuntimeStateStore.storageKey))
    }
}
