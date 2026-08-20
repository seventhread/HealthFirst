import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("常规", systemImage: "gearshape")
                }

            ReminderSettingsView()
                .tabItem {
                    Label("提醒", systemImage: "bell")
                }

            AppearanceSettingsView()
                .tabItem {
                    Label("外观", systemImage: "paintbrush")
                }
        }
        .padding(20)
        .frame(minWidth: 590, idealWidth: 620, minHeight: 480, idealHeight: 540)
    }
}

private struct GeneralSettingsView: View {
    @AppStorage(SettingsKey.launchAtLogin) private var launchAtLogin = false
    @AppStorage(SettingsKey.workdayStartHour) private var workdayStartHour = AppSettings.defaultWorkdayStartHour
    @AppStorage(SettingsKey.workdayEndHour) private var workdayEndHour = AppSettings.defaultWorkdayEndHour
    @AppStorage(SettingsKey.soundEnabled) private var soundEnabled = false

    var body: some View {
        SettingsPage(
            title: "常规",
            subtitle: "决定 HealthFirst 什么时候陪你工作。"
        ) {
            SettingsSection(title: "启动") {
                SettingsToggleRow(
                    title: "登录后自动启动",
                    detail: "当前原型只保存这个偏好；稍后接入 macOS 登录项权限后才会真正生效。",
                    isOn: $launchAtLogin
                )
            }

            SettingsSection(title: "工作时段") {
                HStack(spacing: 14) {
                    HourPicker(title: "开始", selection: $workdayStartHour)
                    Image(systemName: "arrow.right")
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                    HourPicker(title: "结束", selection: $workdayEndHour)
                }

                if workdayStartHour >= workdayEndHour {
                    SettingsNote(
                        text: "结束时间需要晚于开始时间；跨午夜的工作时段暂不支持。",
                        systemImage: "exclamationmark.triangle.fill",
                        color: HealthFirstStyle.orange
                    )
                } else {
                    SettingsNote(
                        text: "工作时段外会暂停自动提醒，手动预览仍可使用。",
                        systemImage: "moon.stars",
                        color: HealthFirstStyle.lavenderDark
                    )
                }
            }

            SettingsSection(title: "声音") {
                SettingsToggleRow(
                    title: "播放轻提示音",
                    detail: "默认关闭。提醒小窗本身不会抢夺键盘焦点。",
                    isOn: $soundEnabled
                )
            }
        }
    }
}

private struct ReminderSettingsView: View {
    @AppStorage(SettingsKey.eyeReminderEnabled) private var eyeReminderEnabled = true
    @AppStorage(SettingsKey.eyeIntervalMinutes) private var eyeIntervalMinutes = AppSettings.defaultEyeIntervalMinutes
    @AppStorage(SettingsKey.standReminderEnabled) private var standReminderEnabled = true
    @AppStorage(SettingsKey.standIntervalMinutes) private var standIntervalMinutes = AppSettings.defaultStandIntervalMinutes
    @AppStorage(SettingsKey.quietReminderEnabled) private var quietReminderEnabled = false
    @AppStorage(SettingsKey.quietDailyCount) private var quietDailyCount = AppSettings.defaultQuietDailyCount

    private let eyeIntervals = [15, 20, 30, 45, 60]

    var body: some View {
        SettingsPage(
            title: "提醒",
            subtitle: "三种提醒彼此独立，需要时再打开。"
        ) {
            SettingsSection(title: "护眼") {
                SettingsToggleRow(
                    title: "望远 20 秒",
                    detail: "默认开启；到点后由角色陪你完成倒计时。",
                    isOn: $eyeReminderEnabled
                )

                SettingsValueRow(title: "提醒间隔", isEnabled: eyeReminderEnabled) {
                    Picker("提醒间隔", selection: $eyeIntervalMinutes) {
                        ForEach(eyeIntervals, id: \.self) { minutes in
                            Text("\(minutes) 分钟").tag(minutes)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 118)
                }
            }

            SettingsSection(title: "站立") {
                SettingsToggleRow(
                    title: "离开椅子活动一下",
                    detail: "默认开启，每次由角色陪伴 60 秒。",
                    isOn: $standReminderEnabled
                )

                SettingsValueRow(title: "提醒间隔", isEnabled: standReminderEnabled) {
                    Stepper(
                        "\(standIntervalMinutes) 分钟",
                        value: $standIntervalMinutes,
                        in: 20...120,
                        step: 10
                    )
                    .frame(width: 150)
                }
            }

            SettingsSection(title: "小动作") {
                SettingsToggleRow(
                    title: "盆底肌轻练习",
                    detail: "默认关闭；启用后只在工作时段内分散提醒。",
                    isOn: $quietReminderEnabled
                )

                SettingsValueRow(title: "每天次数", isEnabled: quietReminderEnabled) {
                    Stepper(
                        "\(quietDailyCount) 次",
                        value: $quietDailyCount,
                        in: 1...6
                    )
                    .frame(width: 120)
                }

                SettingsNote(
                    text: "这不是医疗训练或治疗建议。我们不会询问、记录或上传身体状况；如有不适，请立即停止并咨询专业人士。",
                    systemImage: "hand.raised.fill",
                    color: HealthFirstStyle.lavenderDark
                )
            }
        }
    }
}

private struct AppearanceSettingsView: View {
    @AppStorage(SettingsKey.copyTone) private var copyToneRawValue = AppSettings.defaultCopyTone.rawValue
    @AppStorage(SettingsKey.seriousModeEnabled) private var seriousModeEnabled = false

    private var selectedTone: CopyTone {
        CopyTone(rawValue: copyToneRawValue) ?? AppSettings.defaultCopyTone
    }

    var body: some View {
        SettingsPage(
            title: "外观与语气",
            subtitle: "提醒可以有性格，但不会制造焦虑。"
        ) {
            SettingsSection(title: "文字风格") {
                Picker("文字风格", selection: $copyToneRawValue) {
                    ForEach(CopyTone.allCases) { tone in
                        Text(tone.title).tag(tone.rawValue)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "quote.bubble.fill")
                        .foregroundStyle(HealthFirstStyle.orange)
                    Text(selectedTone.example)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(HealthFirstStyle.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(12)
                .background(HealthFirstStyle.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                .accessibilityElement(children: .combine)
                .accessibilityLabel("示例：\(selectedTone.example)")
            }

            SettingsSection(title: "动态效果") {
                SettingsNote(
                    text: "HealthFirst 始终尊重系统的“减少动态效果”设置；开启后会改用静态反馈和淡入淡出。",
                    systemImage: "accessibility",
                    color: HealthFirstStyle.lavenderDark
                )
            }

            SettingsSection(title: "实验性") {
                SettingsToggleRow(
                    title: "认真模式",
                    detail: "需要你主动开启；二次无回应后会使用全屏陪伴界面，并始终保留右上角“紧急跳过”。",
                    isOn: $seriousModeEnabled
                )

                SettingsNote(
                    text: "认真模式仍在打磨，动画和出现时机可能继续调整。",
                    systemImage: "testtube.2",
                    color: HealthFirstStyle.orange
                )
            }
        }
    }
}

private struct SettingsPage<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(HealthFirstStyle.ink)
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }

                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
            .padding(.bottom, 8)
        }
    }
}

private struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .tracking(0.7)

            VStack(alignment: .leading, spacing: 14) {
                content
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(HealthFirstStyle.secondarySurface)
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(.primary.opacity(0.06))
                    }
            )
        }
    }
}

private struct SettingsToggleRow: View {
    let title: String
    let detail: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(HealthFirstStyle.ink)
                Text(detail)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Toggle(title, isOn: $isOn)
                .labelsHidden()
        }
        .accessibilityElement(children: .contain)
    }
}

private struct SettingsValueRow<Control: View>: View {
    let title: String
    let isEnabled: Bool
    @ViewBuilder let control: Control

    var body: some View {
        HStack(spacing: 16) {
            Text(title)
                .font(.system(size: 13))
                .foregroundStyle(isEnabled ? HealthFirstStyle.ink : .secondary)
            Spacer(minLength: 20)
            control
                .disabled(!isEnabled)
        }
        .opacity(isEnabled ? 1 : 0.55)
    }
}

private struct HourPicker: View {
    let title: String
    @Binding var selection: Int

    var body: some View {
        HStack(spacing: 8) {
            Text(title)
                .foregroundStyle(.secondary)
            Picker(title, selection: $selection) {
                ForEach(0..<24, id: \.self) { hour in
                    Text(String(format: "%02d:00", hour)).tag(hour)
                }
            }
            .labelsHidden()
            .frame(width: 100)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct SettingsNote: View {
    let text: String
    let systemImage: String
    let color: Color

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: systemImage)
                .foregroundStyle(color)
                .frame(width: 16)
            Text(text)
                .font(.system(size: 11.5))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    SettingsView()
}
