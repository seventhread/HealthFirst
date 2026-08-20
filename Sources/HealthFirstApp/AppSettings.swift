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
    static let standReminderEnabled = "reminder.standing.enabled"
    static let standIntervalMinutes = "reminder.standing.intervalMinutes"
    static let quietReminderEnabled = "reminder.quiet.enabled"
    static let quietDailyCount = "reminder.quiet.dailyCount"

    static let copyTone = "copy.tone"
    static let followsSystemReduceMotion = "appearance.followReduceMotion"
    static let seriousModeEnabled = "reminder.mode.serious"
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
    static let defaultStandIntervalMinutes = 40
    static let defaultQuietDailyCount = 3
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
            SettingsKey.standReminderEnabled: true,
            SettingsKey.standIntervalMinutes: defaultStandIntervalMinutes,
            SettingsKey.quietReminderEnabled: false,
            SettingsKey.quietDailyCount: defaultQuietDailyCount,
            SettingsKey.copyTone: defaultCopyTone.rawValue,
            SettingsKey.followsSystemReduceMotion: true,
            SettingsKey.seriousModeEnabled: false
        ])
    }

    static func copyTone(in store: UserDefaults = .standard) -> CopyTone {
        CopyTone(rawValue: store.string(forKey: SettingsKey.copyTone) ?? "") ?? defaultCopyTone
    }
}
