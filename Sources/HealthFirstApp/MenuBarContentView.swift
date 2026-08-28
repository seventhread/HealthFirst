import AppKit
import HealthFirstCore
import SwiftUI

@MainActor
struct MenuBarContentView: View {
    @ObservedObject var model: AppModel
    @State private var pauseOptionsExpanded = false
    @Environment(\.dismiss) private var dismiss

#if DEBUG
    @Environment(\.openWindow) private var openWindow
#endif

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            if model.hasPendingReminder {
                PendingReminderButton {
                    openPendingReminderAfterDismiss()
                }
                .keyboardShortcut(.defaultAction)
                .padding(.top, 12)
            }

            scheduleSection
                .padding(.top, model.hasPendingReminder ? 14 : 16)

            quickActions
                .padding(.top, 14)

            pauseControl
                .padding(.top, 12)

            footer
                .padding(.top, 10)
        }
        .padding(.horizontal, 14)
        .padding(.top, 14)
        .padding(.bottom, 10)
        .frame(width: 344)
        .onChange(of: model.canStartManualPause) { canStartManualPause in
            guard !canStartManualPause else { return }
            pauseOptionsExpanded = false
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            ZStack(alignment: .bottom) {
                Ellipse()
                    .fill(HealthFirstStyle.lavender.opacity(0.12))
                    .frame(width: 58, height: 38)
                    .offset(y: 2)

                ProductionMascotView()
                    .frame(width: 43, height: 50)
            }
            .frame(width: 58, height: 52)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text("HealthFirst")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)

                    StatusBadge(
                        title: statusBadgeText,
                        color: statusBadgeColor
                    )
                }

                Text(statusDetailText)
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("HealthFirst，状态：\(statusBadgeText)，\(statusDetailText)")
    }

    private var scheduleSection: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline) {
                Text("接下来")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .accessibilityAddTraits(.isHeader)

                Spacer()

                SettingsLaunchButton(selectedTab: .reminders) {
                    Label("调整", systemImage: "slider.horizontal.3")
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(HealthFirstStyle.orange)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("设置提醒间隔和陪伴时长")
                .accessibilityHint("打开提醒设置")
            }

            VStack(spacing: 0) {
                if scheduledKinds.isEmpty {
                    HStack(spacing: 10) {
                        Image(systemName: "bell.slash")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 28, height: 28)
                            .background(
                                HealthFirstStyle.lavender.opacity(0.10),
                                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                            )

                        VStack(alignment: .leading, spacing: 1) {
                            Text("暂时没有自动提醒")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.primary)
                            Text("可在“调整”中开启或修改时间")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }

                        Spacer()
                    }
                    .frame(height: 43)
                    .accessibilityElement(children: .combine)
                } else {
                    ForEach(Array(scheduledKinds.enumerated()), id: \.element) { index, kind in
                        let dueDate = model.nextDueDate(for: kind)
                        let isPrimary = kind == nextScheduledKind
                        ScheduleRow(
                            kind: kind,
                            relativeTime: scheduleDisplayText(
                                for: dueDate,
                                isPrimary: isPrimary
                            ),
                            exactTime: exactDueText(for: dueDate),
                            accessibilityTime: accessibleDueText(for: dueDate),
                            isPrimary: isPrimary
                        )

                        if index < scheduledKinds.count - 1 {
                            Divider()
                                .padding(.leading, 40)
                        }
                    }
                }
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 6)
            .background {
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .fill(HealthFirstStyle.secondarySurface.opacity(0.78))
                    .overlay {
                        RoundedRectangle(cornerRadius: 15, style: .continuous)
                            .fill(HealthFirstStyle.lavender.opacity(0.055))
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 15, style: .continuous)
                            .strokeBorder(.primary.opacity(0.065), lineWidth: 1)
                    }
            }
        }
    }

    private var quickActions: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline) {
                Text("现在休息一下")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .accessibilityAddTraits(.isHeader)

                Spacer()

                if let actionUnavailableText {
                    Text(actionUnavailableText)
                        .font(.system(size: 10.5))
                        .foregroundStyle(.tertiary)
                }
            }

            HStack(spacing: 8) {
                ForEach(ReminderKind.allCases, id: \.self) { kind in
                    QuickActionTile(
                        kind: kind,
                        duration: model.configuredGuideDuration(for: kind),
                        isRecommended: kind == nextScheduledKind,
                        isEnabled: model.canTriggerPreview
                    ) {
                        triggerPreviewAfterDismiss(kind)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var pauseControl: some View {
        if model.isPaused {
            PauseResumeButton(until: model.pausedUntil) {
                model.resume()
            }
        } else {
            let canStartManualPause = model.canStartManualPause

            VStack(spacing: 6) {
                Button {
                    withAnimation(.easeInOut(duration: 0.16)) {
                        pauseOptionsExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "pause.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 28, height: 28)
                            .background(
                                HealthFirstStyle.lavender.opacity(0.12),
                                in: Circle()
                            )

                        VStack(alignment: .leading, spacing: 1) {
                            Text("暂停提醒")
                                .font(.system(size: 12.5, weight: .medium))
                                .foregroundStyle(.primary)
                            Text(
                                canStartManualPause
                                    ? "30 分钟、1 小时或到明天"
                                    : "工作时段外无需暂停"
                            )
                                .font(.system(size: 10.5))
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.down")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.tertiary)
                            .rotationEffect(.degrees(pauseOptionsExpanded ? 180 : 0))
                    }
                    .padding(.horizontal, 9)
                    .frame(width: 316, height: 42, alignment: .leading)
                    .background(
                        HealthFirstStyle.secondarySurface.opacity(0.62),
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(.primary.opacity(0.055), lineWidth: 1)
                    }
                    .contentShape(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                    )
                    .opacity(canStartManualPause ? 1 : 0.45)
                }
                .buttonStyle(.plain)
                .disabled(!canStartManualPause)
                .help(
                    canStartManualPause
                        ? "选择暂停时长"
                        : "工作时段外无需暂停"
                )
                .accessibilityLabel(
                    canStartManualPause ? "暂停提醒" : "暂停提醒不可用"
                )
                .accessibilityValue(
                    canStartManualPause
                        ? (pauseOptionsExpanded ? "选项已展开" : "选项已收起")
                        : "当前不在工作时间"
                )
                .accessibilityHint(
                    canStartManualPause
                        ? "显示暂停时长"
                        : "工作时段外无需暂停"
                )

                if pauseOptionsExpanded && canStartManualPause {
                    HStack(spacing: 6) {
                        PauseDurationButton(title: "30 分钟") {
                            pauseOptionsExpanded = false
                            model.pause(for: 30 * 60)
                        }
                        PauseDurationButton(title: "1 小时") {
                            pauseOptionsExpanded = false
                            model.pause(for: 60 * 60)
                        }
                        PauseDurationButton(title: "到明天") {
                            pauseOptionsExpanded = false
                            model.pauseUntilTomorrow()
                        }
                    }
                    .frame(width: 316)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
    }

    private var footer: some View {
        VStack(spacing: 8) {
            Divider()

            HStack(spacing: 8) {
                SettingsLaunchButton(selectedTab: .general) {
                    Label("设置", systemImage: "gearshape")
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .frame(height: 26)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .keyboardShortcut(",")

                Spacer()

                Menu {
#if DEBUG
                    Button {
                        triggerSeriousPreviewAfterDismiss()
                    } label: {
                        Label("预览认真模式", systemImage: "rectangle.inset.filled")
                    }
                    .disabled(!model.canTriggerPreview)

                    Button {
                        NSApp.activate(ignoringOtherApps: true)
                        openWindow(id: "motion-lab")
                    } label: {
                        Label("动作实验室…", systemImage: "hammer")
                    }

                    Divider()
#endif

                    Button {
                        NSApp.terminate(nil)
                    } label: {
                        Label("退出 HealthFirst", systemImage: "power")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 26)
                        .contentShape(Rectangle())
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .help("更多")
                .accessibilityLabel("更多操作")
            }
        }
    }

    private var scheduledKinds: [ReminderKind] {
        ReminderKind.allCases
            .filter { model.nextDueDate(for: $0) != nil }
            .sorted { lhs, rhs in
                guard let left = model.nextDueDate(for: lhs),
                      let right = model.nextDueDate(for: rhs) else {
                    return originalIndex(of: lhs) < originalIndex(of: rhs)
                }
                if left == right {
                    return originalIndex(of: lhs) < originalIndex(of: rhs)
                }
                return left < right
            }
    }

    private var nextScheduledKind: ReminderKind? {
        ReminderKind.allCases
            .compactMap { kind in
                model.nextDueDate(for: kind).map { (kind: kind, date: $0) }
            }
            .min { $0.date < $1.date }?
            .kind
    }

    private var statusBadgeText: String {
        if model.hasPendingReminder { return "待处理" }
        if model.isPaused { return "已暂停" }
        if model.isGuiding { return "陪伴中" }
        if !model.isWithinConfiguredWorkday { return "休息中" }
        return "运行中"
    }

    private var statusBadgeColor: Color {
        if model.hasPendingReminder { return HealthFirstStyle.orange }
        if model.isPaused { return .secondary }
        if !model.isWithinConfiguredWorkday { return .secondary }
        return HealthFirstStyle.lavenderDark
    }

    private var statusDetailText: String {
        if model.hasPendingReminder {
            return "有一张提醒等你处理"
        }

        if model.isPaused, let pausedUntil = model.pausedUntil {
            return "暂停到 \(shortDateTime(pausedUntil))"
        }

        if model.isGuiding, let kind = model.activeReminder?.kind {
            return "正在陪你完成\(kind.displayName)"
        }

        if let kind = nextScheduledKind {
            return "下次\(kind.displayName) · \(relativeDueText(for: model.nextDueDate(for: kind)))"
        }

        return "等待你开启提醒"
    }

    private var actionUnavailableText: String? {
        guard !model.canTriggerPreview else { return nil }
        if model.isPaused { return "恢复后可用" }
        if model.isGuiding { return "完成当前陪伴后可用" }
        return "稍后可用"
    }

    private func originalIndex(of kind: ReminderKind) -> Int {
        ReminderKind.allCases.firstIndex(of: kind) ?? .max
    }

    private func relativeDueText(for date: Date?) -> String {
        guard let date else { return "未开启" }

        let interval = date.timeIntervalSince(model.now)
        if interval <= 30 { return "马上" }

        let minutes = max(1, Int(ceil(interval / 60)))
        if minutes < 60 { return "\(minutes) 分钟后" }

        let calendar = Calendar.autoupdatingCurrent
        if minutes < 6 * 60, calendar.isDateInToday(date) {
            return "约 \(Int(ceil(Double(minutes) / 60))) 小时后"
        }

        let days = dayDistance(to: date, calendar: calendar)
        if days == 1 { return "明天" }
        if days > 1, days <= 7 { return "\(days) 天后" }

        return date.formatted(.dateTime.month(.abbreviated).day())
    }

    private func exactDueText(for date: Date?) -> String? {
        guard let date else { return nil }
        let calendar = Calendar.autoupdatingCurrent
        let time = date.formatted(date: .omitted, time: .shortened)

        if calendar.isDateInToday(date) { return "今天 \(time)" }
        if calendar.isDateInTomorrow(date) { return "明天 \(time)" }

        let days = dayDistance(to: date, calendar: calendar)
        if days > 1, days <= 7 {
            return date.formatted(
                .dateTime.weekday(.abbreviated).hour().minute()
            )
        }

        return date.formatted(
            .dateTime.month(.abbreviated).day().hour().minute()
        )
    }

    private func scheduleDisplayText(for date: Date?, isPrimary: Bool) -> String {
        let relative = relativeDueText(for: date)
        guard !isPrimary,
              let date,
              date.timeIntervalSince(model.now) >= 6 * 60 * 60 else {
            return relative
        }
        return exactDueText(for: date) ?? relative
    }

    private func accessibleDueText(for date: Date?) -> String {
        guard let date else { return "未开启" }
        return date.formatted(date: .complete, time: .shortened)
    }

    private func shortDateTime(_ date: Date) -> String {
        let calendar = Calendar.autoupdatingCurrent
        let time = date.formatted(date: .omitted, time: .shortened)
        if calendar.isDateInToday(date) { return time }
        if calendar.isDateInTomorrow(date) { return "明天 \(time)" }

        let days = dayDistance(to: date, calendar: calendar)
        if days > 1, days <= 7 {
            return date.formatted(
                .dateTime.weekday(.abbreviated).hour().minute()
            )
        }

        return date.formatted(
            .dateTime.month(.abbreviated).day().hour().minute()
        )
    }

    private func dayDistance(to date: Date, calendar: Calendar) -> Int {
        let today = calendar.startOfDay(for: model.now)
        let dueDay = calendar.startOfDay(for: date)
        return calendar.dateComponents([.day], from: today, to: dueDay).day ?? 0
    }

    private func triggerPreviewAfterDismiss(_ kind: ReminderKind) {
        dismiss()
        Task { @MainActor in
            // Let MenuBarExtra commit its dismissal before the independent
            // reminder panel becomes key, so the two surfaces never stack.
            await Task.yield()
            model.triggerPreview(kind)
        }
    }

    private func openPendingReminderAfterDismiss() {
        dismiss()
        Task { @MainActor in
            await Task.yield()
            model.openPendingReminder()
        }
    }

#if DEBUG
    private func triggerSeriousPreviewAfterDismiss() {
        dismiss()
        Task { @MainActor in
            await Task.yield()
            model.triggerSeriousPreview()
        }
    }
#endif

}

private struct SettingsLaunchButton<Label: View>: View {
    let selectedTab: SettingsTab
    let label: Label

    init(
        selectedTab: SettingsTab,
        @ViewBuilder label: () -> Label
    ) {
        self.selectedTab = selectedTab
        self.label = label()
    }

    @ViewBuilder
    var body: some View {
        if #available(macOS 14.0, *) {
            ModernSettingsLaunchButton(
                selectedTab: selectedTab,
                label: label
            )
        } else {
            Button {
                selectTab()
                NSApp.activate(ignoringOtherApps: true)
                NSApp.sendAction(
                    Selector(("showSettingsWindow:")),
                    to: nil,
                    from: nil
                )
            } label: {
                label
            }
        }
    }

    private func selectTab() {
        UserDefaults.standard.set(
            selectedTab.rawValue,
            forKey: SettingsKey.selectedSettingsTab
        )
    }
}

@available(macOS 14.0, *)
private struct ModernSettingsLaunchButton<Label: View>: View {
    let selectedTab: SettingsTab
    let label: Label

    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Button {
            UserDefaults.standard.set(
                selectedTab.rawValue,
                forKey: SettingsKey.selectedSettingsTab
            )
            NSApp.activate(ignoringOtherApps: true)
            openSettings()
        } label: {
            label
        }
    }
}

private struct StatusBadge: View {
    let title: String
    let color: Color

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 5, height: 5)

            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 7)
        .frame(height: 20)
        .background(
            HealthFirstStyle.secondarySurface.opacity(0.72),
            in: Capsule()
        )
        .accessibilityHidden(true)
    }
}

private struct PendingReminderButton: View {
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: "bookmark.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(HealthFirstStyle.orange)
                    .frame(width: 30, height: 30)
                    .background(
                        HealthFirstStyle.orange.opacity(0.12),
                        in: Circle()
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text("有一张提醒夹在这里")
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text("小家伙替你保管好了")
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text("打开")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(HealthFirstStyle.orange)

                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(HealthFirstStyle.orange.opacity(0.72))
            }
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
            .background(
                HealthFirstStyle.orange.opacity(isHovering ? 0.115 : 0.075),
                in: RoundedRectangle(cornerRadius: 13, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .strokeBorder(HealthFirstStyle.orange.opacity(0.16), lineWidth: 1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovering = hovering
        }
        .animation(
            reduceMotion ? nil : .easeOut(duration: 0.12),
            value: isHovering
        )
        .accessibilityLabel("打开待处理提醒")
        .accessibilityHint("小家伙替你保管了一张提醒")
    }
}

private struct ScheduleRow: View {
    let kind: ReminderKind
    let relativeTime: String
    let exactTime: String?
    let accessibilityTime: String
    let isPrimary: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: kind.symbolName)
                .font(.system(size: isPrimary ? 13 : 11.5, weight: .semibold))
                .foregroundStyle(isPrimary ? HealthFirstStyle.orange : Color.secondary)
                .frame(
                    width: isPrimary ? 30 : 27,
                    height: isPrimary ? 30 : 27
                )
                .background(
                    (isPrimary ? HealthFirstStyle.orange : HealthFirstStyle.lavender)
                        .opacity(isPrimary ? 0.12 : 0.10),
                    in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                )

            VStack(alignment: .leading, spacing: 1) {
                Text(kind.displayName)
                    .font(.system(size: isPrimary ? 12.5 : 12, weight: isPrimary ? .semibold : .medium))
                    .foregroundStyle(.primary)

                if isPrimary, let exactTime {
                    Text(exactTime)
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            Text(relativeTime)
                .font(.system(size: isPrimary ? 12 : 11.5, weight: isPrimary ? .semibold : .regular))
                .foregroundStyle(isPrimary ? AnyShapeStyle(HealthFirstStyle.orange) : AnyShapeStyle(.secondary))
                .monospacedDigit()
                .lineLimit(1)
        }
        .frame(height: isPrimary ? 49 : 36)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(kind.displayName)，\(relativeTime)，\(accessibilityTime)")
    }
}

private struct QuickActionTile: View {
    let kind: ReminderKind
    let duration: TimeInterval
    let isRecommended: Bool
    let isEnabled: Bool
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: kind.symbolName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(
                        isRecommended
                            ? AnyShapeStyle(HealthFirstStyle.orange)
                            : AnyShapeStyle(.secondary)
                    )

                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(kind.displayName)
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text(durationText)
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(
                tileBackground,
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .overlay {
                if isHovering {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(tileBorderColor, lineWidth: 1)
                }
            }
            .contentShape(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.48)
        .onHover { hovering in
            guard isEnabled else { return }
            isHovering = hovering
        }
        .animation(
            reduceMotion ? nil : .easeOut(duration: 0.12),
            value: isHovering
        )
        .accessibilityLabel(
            "立即开始\(kind.displayName)，\(durationText)"
        )
        .accessibilityHint(isEnabled ? "打开陪伴提醒" : "当前暂不可用")
    }

    private var tileBackground: some ShapeStyle {
        let baseOpacity = isRecommended ? 0.09 : 0.075
        let hoverBoost = isHovering ? 0.055 : 0
        let color = isRecommended ? HealthFirstStyle.orange : HealthFirstStyle.lavender
        return color.opacity(baseOpacity + hoverBoost)
    }

    private var tileBorderColor: Color {
        if isHovering {
            return (isRecommended ? HealthFirstStyle.orange : HealthFirstStyle.lavender)
                .opacity(0.20)
        }
        return .clear
    }

    private var durationText: String {
        let seconds = max(0, Int(duration.rounded()))
        if seconds >= 60, seconds.isMultiple(of: 60) {
            return "\(seconds / 60) 分钟"
        }
        return "\(seconds) 秒"
    }
}

private struct PauseResumeButton: View {
    let until: Date?
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: "play.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(HealthFirstStyle.orange)
                    .frame(width: 28, height: 28)
                    .background(
                        HealthFirstStyle.orange.opacity(0.12),
                        in: Circle()
                    )

                VStack(alignment: .leading, spacing: 1) {
                    Text("提醒已暂停")
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(.primary)
                    if let until {
                        Text("到 \(until.formatted(date: .omitted, time: .shortened))")
                            .font(.system(size: 10.5))
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Text("继续")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(HealthFirstStyle.orange)

                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(HealthFirstStyle.orange.opacity(0.72))
            }
            .padding(.horizontal, 9)
            .frame(maxWidth: .infinity, minHeight: 42, alignment: .leading)
            .background(
                HealthFirstStyle.orange.opacity(isHovering ? 0.105 : 0.07),
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(HealthFirstStyle.orange.opacity(0.14), lineWidth: 1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovering = hovering
        }
        .accessibilityLabel("继续提醒")
        .accessibilityHint("恢复所有提醒倒计时")
    }
}

private struct PauseDurationButton: View {
    let title: String
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(isHovering ? HealthFirstStyle.orange : .secondary)
                .frame(maxWidth: .infinity, minHeight: 30)
                .background(
                    (isHovering ? HealthFirstStyle.orange : HealthFirstStyle.lavender)
                        .opacity(isHovering ? 0.10 : 0.065),
                    in: RoundedRectangle(cornerRadius: 9, style: .continuous)
                )
                .contentShape(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovering = hovering
        }
        .accessibilityLabel("暂停提醒\(title)")
    }
}
