import XCTest
@testable import HealthFirstApp

final class AppSettingsTests: XCTestCase {
    func testStandingIntervalMenuPreservesTheStepperRange() {
        XCTAssertEqual(
            ReminderSettingsOptions.standingIntervals,
            Array(stride(from: 20, through: 120, by: 10))
        )
        XCTAssertTrue(
            ReminderSettingsOptions.standingIntervals.contains(
                AppSettings.defaultStandIntervalMinutes
            )
        )
    }

    func testRegisteredGuideDurationsAndSettingsTabDefaults() throws {
        let suiteName = "HealthFirstAppTests.\(UUID().uuidString)"
        let store = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { store.removePersistentDomain(forName: suiteName) }

        AppSettings.registerDefaults(in: store)

        XCTAssertEqual(
            store.integer(forKey: SettingsKey.eyeGuideDurationSeconds),
            20
        )
        XCTAssertEqual(
            store.integer(forKey: SettingsKey.standGuideDurationSeconds),
            60
        )
        XCTAssertEqual(
            store.integer(forKey: SettingsKey.quietGuideDurationSeconds),
            30
        )
        XCTAssertEqual(
            store.string(forKey: SettingsKey.selectedSettingsTab),
            SettingsTab.general.rawValue
        )
    }

    func testDurationTitlesNeverIncludeRecommendationMetadata() {
        XCTAssertEqual(
            DurationOptionFormatter.selectionTitle(seconds: 20),
            "20 秒"
        )
        XCTAssertEqual(
            DurationOptionFormatter.selectionTitle(seconds: 60),
            "1 分钟"
        )
        XCTAssertEqual(
            DurationOptionFormatter.selectionTitle(seconds: 90),
            "90 秒"
        )
        XCTAssertEqual(
            DurationOptionFormatter.selectionTitle(seconds: 120),
            "2 分钟"
        )

        for seconds in [20, 30, 45, 60, 90, 120] {
            XCTAssertFalse(
                DurationOptionFormatter.selectionTitle(seconds: seconds)
                    .contains("推荐")
            )
        }
    }

    func testWorkdayHoursAlwaysNormalizeToASameDayWindow() {
        XCTAssertEqual(
            WorkdayHoursPolicy.normalized(startHour: 9, endHour: 18),
            WorkdayHours(startHour: 9, endHour: 18)
        )
        XCTAssertEqual(
            WorkdayHoursPolicy.normalized(startHour: 9, endHour: 9),
            WorkdayHours(startHour: 9, endHour: 10)
        )
        XCTAssertEqual(
            WorkdayHoursPolicy.normalized(startHour: 18, endHour: 9),
            WorkdayHours(startHour: 18, endHour: 19)
        )
        XCTAssertEqual(
            WorkdayHoursPolicy.normalized(startHour: 23, endHour: 0),
            WorkdayHours(startHour: 22, endHour: 23)
        )
    }

    func testWorkdayPickerOptionsCannotCreateCrossMidnightHours() {
        XCTAssertEqual(
            WorkdayHoursPolicy.startOptions(endingAt: 3),
            [0, 1, 2]
        )
        XCTAssertEqual(
            WorkdayHoursPolicy.endOptions(startingAt: 20),
            [21, 22, 23]
        )

        for endHour in 1...23 {
            XCTAssertTrue(
                WorkdayHoursPolicy.startOptions(endingAt: endHour)
                    .allSatisfy { $0 < endHour }
            )
        }

        for startHour in 0...22 {
            XCTAssertTrue(
                WorkdayHoursPolicy.endOptions(startingAt: startHour)
                    .allSatisfy { $0 > startHour }
            )
        }
    }

    func testRegisterDefaultsRepairsPreviouslySavedInvalidWorkday() throws {
        let suiteName = "HealthFirstAppTests.\(UUID().uuidString)"
        let store = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { store.removePersistentDomain(forName: suiteName) }

        store.set(18, forKey: SettingsKey.workdayStartHour)
        store.set(9, forKey: SettingsKey.workdayEndHour)

        AppSettings.registerDefaults(in: store)

        XCTAssertEqual(
            store.integer(forKey: SettingsKey.workdayStartHour),
            18
        )
        XCTAssertEqual(
            store.integer(forKey: SettingsKey.workdayEndHour),
            19
        )
    }

    func testRegisterDefaultsRepairsInvalidReminderSelections() throws {
        let suiteName = "HealthFirstAppTests.\(UUID().uuidString)"
        let store = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { store.removePersistentDomain(forName: suiteName) }

        store.set(17, forKey: SettingsKey.eyeIntervalMinutes)
        store.set(19, forKey: SettingsKey.eyeGuideDurationSeconds)
        store.set(37, forKey: SettingsKey.standIntervalMinutes)
        store.set(75, forKey: SettingsKey.standGuideDurationSeconds)
        store.set(12, forKey: SettingsKey.quietDailyCount)
        store.set(31, forKey: SettingsKey.quietGuideDurationSeconds)

        AppSettings.registerDefaults(in: store)

        XCTAssertEqual(
            store.integer(forKey: SettingsKey.eyeIntervalMinutes),
            AppSettings.defaultEyeIntervalMinutes
        )
        XCTAssertEqual(
            store.integer(forKey: SettingsKey.eyeGuideDurationSeconds),
            AppSettings.defaultEyeGuideDurationSeconds
        )
        XCTAssertEqual(
            store.integer(forKey: SettingsKey.standIntervalMinutes),
            AppSettings.defaultStandIntervalMinutes
        )
        XCTAssertEqual(
            store.integer(forKey: SettingsKey.standGuideDurationSeconds),
            AppSettings.defaultStandGuideDurationSeconds
        )
        XCTAssertEqual(
            store.integer(forKey: SettingsKey.quietDailyCount),
            ReminderSettingsOptions.quietDailyCountRange.upperBound
        )
        XCTAssertEqual(
            store.integer(forKey: SettingsKey.quietGuideDurationSeconds),
            AppSettings.defaultQuietGuideDurationSeconds
        )
    }

    func testLaunchAtLoginPresentationMapsServiceStates() {
        let disabled = LaunchAtLoginPolicy.presentation(for: .disabled)
        XCTAssertFalse(disabled.isEnabled)
        XCTAssertTrue(disabled.canToggle)
        XCTAssertFalse(disabled.showsSystemSettingsButton)

        let enabled = LaunchAtLoginPolicy.presentation(for: .enabled)
        XCTAssertTrue(enabled.isEnabled)
        XCTAssertTrue(enabled.canToggle)

        let approval = LaunchAtLoginPolicy.presentation(
            for: .requiresApproval
        )
        XCTAssertTrue(approval.isEnabled)
        XCTAssertTrue(approval.canToggle)
        XCTAssertTrue(approval.showsSystemSettingsButton)
        XCTAssertTrue(approval.detail.contains("系统设置"))

        let unavailable = LaunchAtLoginPolicy.presentation(for: .unavailable)
        XCTAssertFalse(unavailable.isEnabled)
        XCTAssertFalse(unavailable.canToggle)
    }

    @MainActor
    func testLaunchAtLoginControllerPersistsConfirmedSystemState() throws {
        let suiteName = "HealthFirstAppTests.\(UUID().uuidString)"
        let store = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { store.removePersistentDomain(forName: suiteName) }

        let service = FakeLaunchAtLoginService(state: .disabled)
        let controller = LaunchAtLoginController(
            service: service,
            store: store
        )

        controller.setEnabled(true)

        XCTAssertEqual(service.state, .enabled)
        XCTAssertTrue(controller.presentation.isEnabled)
        XCTAssertTrue(store.bool(forKey: SettingsKey.launchAtLogin))
        XCTAssertNil(controller.errorMessage)
    }

    @MainActor
    func testLaunchAtLoginControllerRollsBackWhenRegistrationFails() throws {
        let suiteName = "HealthFirstAppTests.\(UUID().uuidString)"
        let store = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { store.removePersistentDomain(forName: suiteName) }

        let service = FakeLaunchAtLoginService(state: .disabled)
        service.registrationError = NSError(
            domain: "HealthFirstAppTests",
            code: 1
        )
        let controller = LaunchAtLoginController(
            service: service,
            store: store
        )

        controller.setEnabled(true)

        XCTAssertEqual(service.state, .disabled)
        XCTAssertFalse(controller.presentation.isEnabled)
        XCTAssertFalse(store.bool(forKey: SettingsKey.launchAtLogin))
        XCTAssertTrue(controller.errorMessage?.contains("设置已恢复") == true)
    }

    @MainActor
    func testNonAppTestRuntimeDoesNotOverwriteSavedLoginPreference() throws {
        let suiteName = "HealthFirstAppTests.\(UUID().uuidString)"
        let store = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { store.removePersistentDomain(forName: suiteName) }
        store.set(true, forKey: SettingsKey.launchAtLogin)

        let service = FakeLaunchAtLoginService(state: .unavailable)
        let controller = LaunchAtLoginController(
            service: service,
            store: store
        )

        XCTAssertFalse(controller.presentation.canToggle)
        XCTAssertTrue(store.bool(forKey: SettingsKey.launchAtLogin))
    }
}

@MainActor
private final class FakeLaunchAtLoginService: LaunchAtLoginServicing {
    var state: LaunchAtLoginRegistrationState
    var registrationError: Error?
    private(set) var didOpenSystemSettings = false

    init(state: LaunchAtLoginRegistrationState) {
        self.state = state
    }

    func setRegistrationEnabled(_ isEnabled: Bool) throws {
        if let registrationError {
            throw registrationError
        }
        state = isEnabled ? .enabled : .disabled
    }

    func openSystemSettings() {
        didOpenSystemSettings = true
    }
}
