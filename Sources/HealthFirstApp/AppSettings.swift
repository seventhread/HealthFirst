import Foundation

/// Stable keys shared by the settings UI and the app's scheduling layer.
///
/// Keep the raw values unchanged when renaming UI labels so existing users do
/// not lose their preferences after an update.
enum SettingsKey {
    static let launchAtLogin = "app.launchAtLogin"
    static let workdayStartHour = "app.workStartHour"
    static let workdayEndHour = "app.workEndHour"
    static let soundEnabled = "app.sound.enabled"

    static let eyeReminderEnabled = "reminder.eye.enabled"
    static let eyeIntervalMinutes = "reminder.eye.intervalMinutes"
    static let eyeGuideDurationSeconds = "reminder.eye.guideSeconds"
    static let standReminderEnabled = "reminder.standing.enabled"
    static let standIntervalMinutes = "reminder.standing.intervalMinutes"
    static let standGuideDurationSeconds = "reminder.standing.guideSeconds"
    static let quietReminderEnabled = "reminder.quiet.enabled"
    static let quietDailyCount = "reminder.quiet.dailyCount"
    static let quietGuideDurationSeconds = "reminder.quiet.guideSeconds"

    static let copyTone = "copy.tone"
    static let seriousModeEnabled = "reminder.mode.serious"
    static let selectedSettingsTab = "settings.selectedTab"
}

enum ReminderSettingsOptions {
    static let eyeIntervals = [15, 20, 30, 45, 60]
    static let eyeDurations = [20, 30, 45, 60]
    static let standingIntervals = Array(
        stride(from: 20, through: 120, by: 10)
    )
    static let standingDurations = [60, 90, 120]
    static let quietDailyCountRange = 1...6
    static let quietDurations = [15, 30, 45, 60]
}

enum CopyTone: String, CaseIterable, Codable, Identifiable, Sendable {
    case gentle
    case dryHumor
    case sharp
    case minimal

    var id: String { rawValue }

    var title: String {
        switch self {
        case .gentle: "温柔"
        case .dryHumor: "冷幽默"
        case .sharp: "毒舌"
        case .minimal: "极简"
        }
    }

    var example: String {
        switch self {
        case .gentle: "眼睛辛苦了，我们望远二十秒。"
        case .dryHumor: "屏幕不会跑，远处可能快忘了你。"
        case .sharp: "再盯下去，屏幕都替你眼睛累。"
        case .minimal: "望远 · 20 秒"
        }
    }
}

enum AppSettings {
    static let defaultWorkdayStartHour = 9
    static let defaultWorkdayEndHour = 18
    static let defaultEyeIntervalMinutes = 20
    static let defaultEyeGuideDurationSeconds = 20
    static let defaultStandIntervalMinutes = 40
    static let defaultStandGuideDurationSeconds = 60
    static let defaultQuietDailyCount = 3
    static let defaultQuietGuideDurationSeconds = 30
    static let defaultCopyTone = CopyTone.gentle

    /// Registers defaults without overwriting values the user has already set.
    /// Call once during application launch before the scheduler reads settings.
    static func registerDefaults(in store: UserDefaults = .standard) {
        store.register(defaults: [
            SettingsKey.launchAtLogin: false,
            SettingsKey.workdayStartHour: defaultWorkdayStartHour,
            SettingsKey.workdayEndHour: defaultWorkdayEndHour,
            SettingsKey.soundEnabled: false,
            SettingsKey.eyeReminderEnabled: true,
            SettingsKey.eyeIntervalMinutes: defaultEyeIntervalMinutes,
            SettingsKey.eyeGuideDurationSeconds: defaultEyeGuideDurationSeconds,
            SettingsKey.standReminderEnabled: true,
            SettingsKey.standIntervalMinutes: defaultStandIntervalMinutes,
            SettingsKey.standGuideDurationSeconds: defaultStandGuideDurationSeconds,
            SettingsKey.quietReminderEnabled: false,
            SettingsKey.quietDailyCount: defaultQuietDailyCount,
            SettingsKey.quietGuideDurationSeconds: defaultQuietGuideDurationSeconds,
            SettingsKey.copyTone: defaultCopyTone.rawValue,
            SettingsKey.seriousModeEnabled: false,
            SettingsKey.selectedSettingsTab: SettingsTab.general.rawValue
        ])

        let normalizedHours = WorkdayHoursPolicy.normalized(
            startHour: store.integer(forKey: SettingsKey.workdayStartHour),
            endHour: store.integer(forKey: SettingsKey.workdayEndHour)
        )
        if normalizedHours.startHour
            != store.integer(forKey: SettingsKey.workdayStartHour) {
            store.set(
                normalizedHours.startHour,
                forKey: SettingsKey.workdayStartHour
            )
        }
        if normalizedHours.endHour
            != store.integer(forKey: SettingsKey.workdayEndHour) {
            store.set(
                normalizedHours.endHour,
                forKey: SettingsKey.workdayEndHour
            )
        }


        repairSelection(
            SettingsKey.eyeIntervalMinutes,
            allowedValues: ReminderSettingsOptions.eyeIntervals,
            fallback: defaultEyeIntervalMinutes,
            in: store
        )
        repairSelection(
            SettingsKey.eyeGuideDurationSeconds,
            allowedValues: ReminderSettingsOptions.eyeDurations,
            fallback: defaultEyeGuideDurationSeconds,
            in: store
        )
        repairSelection(
            SettingsKey.standIntervalMinutes,
            allowedValues: ReminderSettingsOptions.standingIntervals,
            fallback: defaultStandIntervalMinutes,
            in: store
        )
        repairSelection(
            SettingsKey.standGuideDurationSeconds,
            allowedValues: ReminderSettingsOptions.standingDurations,
            fallback: defaultStandGuideDurationSeconds,
            in: store
        )
        repairSelection(
            SettingsKey.quietGuideDurationSeconds,
            allowedValues: ReminderSettingsOptions.quietDurations,
            fallback: defaultQuietGuideDurationSeconds,
            in: store
        )

        let quietDailyCount = store.integer(
            forKey: SettingsKey.quietDailyCount
        )
        let repairedQuietDailyCount = min(
            max(
                quietDailyCount,
                ReminderSettingsOptions.quietDailyCountRange.lowerBound
            ),
            ReminderSettingsOptions.quietDailyCountRange.upperBound
        )
        if repairedQuietDailyCount != quietDailyCount {
            store.set(
                repairedQuietDailyCount,
                forKey: SettingsKey.quietDailyCount
            )
        }
    }

    static func copyTone(in store: UserDefaults = .standard) -> CopyTone {
        CopyTone(rawValue: store.string(forKey: SettingsKey.copyTone) ?? "") ?? defaultCopyTone
    }

    private static func repairSelection(
        _ key: String,
        allowedValues: [Int],
        fallback: Int,
        in store: UserDefaults
    ) {
        let value = store.integer(forKey: key)
        guard !allowedValues.contains(value) else { return }
        store.set(fallback, forKey: key)
    }
}

struct WorkdayHours: Equatable {
    let startHour: Int
    let endHour: Int
}

enum WorkdayHoursPolicy {
    /// Repairs preferences written by an older build while preserving as much
    /// of the user's selection as possible. Cross-midnight schedules are not
    /// supported, so the result always has at least a one-hour window.
    static func normalized(startHour: Int, endHour: Int) -> WorkdayHours {
        let start = min(max(startHour, 0), 22)
        let end = min(max(endHour, 1), 23)

        guard start >= end else {
            return WorkdayHours(startHour: start, endHour: end)
        }

        return WorkdayHours(
            startHour: start,
            endHour: min(start + 1, 23)
        )
    }

    static func startOptions(endingAt endHour: Int) -> [Int] {
        let normalizedEnd = min(max(endHour, 1), 23)
        return Array(0..<normalizedEnd)
    }

    static func endOptions(startingAt startHour: Int) -> [Int] {
        let normalizedStart = min(max(startHour, 0), 22)
        return Array((normalizedStart + 1)...23)
    }
}

enum SettingsTab: String {
    case general
    case reminders
    case appearance
}
