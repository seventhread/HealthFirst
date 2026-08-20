import AppKit
import HealthFirstCore
import SwiftUI

@MainActor
struct MenuBarContentView: View {
    @ObservedObject var model: AppModel

#if DEBUG
    @Environment(\.openWindow) private var openWindow
#endif

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            if model.hasPendingReminder {
                pendingCard
            }

            scheduleSection
            quickActions

            Divider()

            HStack {
                Button("设置…") {
                    NSApp.activate(ignoringOtherApps: true)
                    NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                }
                .keyboardShortcut(",")

                Spacer()

                Button("退出") {
                    NSApp.terminate(nil)
                }
            }
            .buttonStyle(.borderless)
        }
        .padding(16)
        .frame(width: 330)
    }

    private var header: some View {
        HStack(spacing: 11) {
            ProductionMascotView()
                .frame(width: 38, height: 44)

            VStack(alignment: .leading, spacing: 2) {
                Text("HealthFirst")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                Text(statusText)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if model.isPaused {
                Button("继续") { model.resume() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
    }

    private var pendingCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("有一张提醒夹在这里", systemImage: "bookmark.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(HealthFirstStyle.lavenderDark)
            Button("打开待处理提醒") {
                model.openPendingReminder()
            }
            .buttonStyle(PrimaryActionButtonStyle())
        }
        .padding(12)
        .background(HealthFirstStyle.lavender.opacity(0.18), in: RoundedRectangle(cornerRadius: 13))
    }

    private var scheduleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("下一次")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)

            ForEach(ReminderKind.allCases, id: \.self) { kind in
                HStack {
                    Label(kind.displayName, systemImage: kind.symbolName)
                    Spacer()
                    Text(nextDueText(for: kind))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                .font(.system(size: 12))
            }
        }
        .padding(12)
        .background(HealthFirstStyle.secondarySurface.opacity(0.65), in: RoundedRectangle(cornerRadius: 13))
    }

    private var quickActions: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 8) {
                Button("现在护眼") { model.triggerPreview(.eye) }
                Button("现在站立") { model.triggerPreview(.standing) }
            }
            .disabled(!model.canTriggerPreview)

            Button("现在做一小段动作") {
                model.triggerPreview(.quietPractice)
            }
            .disabled(!model.canTriggerPreview)

            Menu("暂停提醒") {
                Button("30 分钟") { model.pause(for: 30 * 60) }
                Button("1 小时") { model.pause(for: 60 * 60) }
                Button("到明天上班") { model.pauseUntilTomorrow() }
            }

#if DEBUG
            Divider()
            Button("调试：预览认真模式") {
                model.triggerSeriousPreview()
            }
            .disabled(!model.canTriggerPreview)

            Button("动作实验室…") {
                NSApp.activate(ignoringOtherApps: true)
                openWindow(id: "motion-lab")
            }
#endif
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }

    private var statusText: String {
        if model.hasPendingReminder { return "有一件小事等你处理" }
        if model.isPaused, let pausedUntil = model.pausedUntil {
            return "暂停到 \(pausedUntil.formatted(date: .omitted, time: .shortened))"
        }
        if model.isGuiding { return "正在陪你做一小段" }
        return "安静运行中"
    }

    private func nextDueText(for kind: ReminderKind) -> String {
        guard let date = model.nextDueDate(for: kind) else { return "未开启" }
        return date.formatted(date: .omitted, time: .shortened)
    }
}
