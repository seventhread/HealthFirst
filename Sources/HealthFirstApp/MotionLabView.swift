#if DEBUG
import HealthFirstCore
import SwiftUI

/// A visual-only playground for reviewing mascot and guidance motion without
/// waiting for a real reminder. Nothing in this view talks to `AppModel`.
struct MotionLabView: View {
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @State private var selectedMotion: MascotMotion = .entering
    @State private var selectedKind: ReminderKind = .eye
    @State private var visualStage: VisualPreviewStage = .guidance
    @State private var progress = 0.35
    @State private var reduceMotion = false
    @State private var mascotReplayStartedAt = Date()

    var body: some View {
        VStack(spacing: 0) {
            // SwiftUI's standalone debug Window uses a full-size titlebar on
            // macOS. Keep the lab header below those controls instead of
            // letting its first row sit underneath them.
            Color.clear
                .frame(height: 28)

            header

            Divider()

            HStack(alignment: .top, spacing: 22) {
                controls
                    .frame(width: 232)

                Divider()

                previews
                    .frame(maxWidth: .infinity)
            }
            .padding(22)
        }
        .frame(minWidth: 760, minHeight: 690)
        .background(HealthFirstStyle.surface)
        .onChange(of: selectedMotion) { _ in
            mascotReplayStartedAt = Date()
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(HealthFirstStyle.lavender.opacity(0.22))
                Image(systemName: "sparkles.rectangle.stack")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(HealthFirstStyle.lavenderDark)
            }
            .frame(width: 38, height: 38)

            VStack(alignment: .leading, spacing: 2) {
                Text("动作实验室")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                Text("这里的操作只预览画面，不会触发或改动提醒。")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(effectiveReduceMotion ? "减少动态" : "完整动态")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(effectiveReduceMotion ? .secondary : HealthFirstStyle.orange)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(
                            effectiveReduceMotion
                                ? Color.secondary.opacity(0.10)
                                : HealthFirstStyle.orange.opacity(0.10)
                        )
                )
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 16)
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 18) {
            controlSection(title: "角色动作", systemImage: "figure.wave") {
                Picker("动作", selection: $selectedMotion) {
                    ForEach(Self.motionOptions) { option in
                        Label(option.title, systemImage: option.systemImage)
                            .tag(option.motion)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)

                Text(selectedMotionOption.note)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Button {
                    mascotReplayStartedAt = Date()
                } label: {
                    Label("重新播放动作", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.borderedProminent)
                .tint(HealthFirstStyle.orange)
            }

            controlSection(title: "引导视觉", systemImage: "rectangle.3.group") {
                Picker("预览阶段", selection: $visualStage) {
                    ForEach(VisualPreviewStage.allCases) { stage in
                        Text(stage.title).tag(stage)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)

                Picker("提醒类型", selection: $selectedKind) {
                    ForEach(ReminderKind.allCases, id: \.self) { kind in
                        Text(kind.displayName)
                            .tag(kind)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("进度")
                        Spacer()
                        Text(progress, format: .percent.precision(.fractionLength(0)))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    .font(.system(size: 12, weight: .medium))

                    Slider(value: $progress, in: 0...1)
                        .tint(HealthFirstStyle.orange)
                        .accessibilityLabel("引导进度")
                        .accessibilityValue(visualProgressAccessibilityValue)

                    if selectedKind == .standing {
                        HStack(spacing: 8) {
                            Text(standingElapsed, format: .number.precision(.fractionLength(1)))
                                + Text(" 秒")
                            Spacer(minLength: 4)
                            Text(standingMilestone)
                        }
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                    }
                }
            }

            Toggle("模拟“减少动态效果”", isOn: $reduceMotion)
                .toggleStyle(.switch)
                .font(.system(size: 12, weight: .medium))

            Spacer(minLength: 0)
        }
    }

    private var previews: some View {
        VStack(spacing: 16) {
            previewCard(title: "角色", subtitle: selectedMotionOption.title) {
                TimelineView(
                    .animation(
                        minimumInterval: effectiveReduceMotion ? 0.1 : 1.0 / 30.0,
                        paused: false
                    )
                ) { context in
                    HStack(spacing: 20) {
                        ZStack {
                            Circle()
                                .fill(HealthFirstStyle.lavender.opacity(0.11))
                                .frame(width: 210, height: 210)

                            ProductionMascotView(
                                motion: selectedMotion,
                                progress: progress,
                                actionProgress: mascotPreviewProgress(at: context.date),
                                reduceMotion: effectiveReduceMotion
                            )
                            .frame(width: 154, height: 180)
                        }

                        VStack(spacing: 8) {
                            Text("真实提醒尺寸")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.secondary)

                            ZStack {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(HealthFirstStyle.surface)
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .strokeBorder(.primary.opacity(0.08))
                                    }

                                ProductionMascotView(
                                    motion: selectedMotion,
                                    progress: progress,
                                    actionProgress: mascotPreviewProgress(at: context.date),
                                    reduceMotion: effectiveReduceMotion
                                )
                                .frame(width: 106, height: 124)
                            }
                            .frame(width: 122, height: 140)

                            Text("106 × 124 pt")
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 238)
            }

            previewCard(
                title: visualStage.title,
                subtitle: visualPreviewSubtitle
            ) {
                Group {
                    switch visualStage {
                    case .guidance:
                        if selectedKind == .standing {
                            StandingMotionLabStage(
                                stage: .guidance,
                                progress: progress,
                                reduceMotion: effectiveReduceMotion
                            )
                        } else {
                            GuidanceChromePreview(
                                kind: selectedKind,
                                progress: progress,
                                reduceMotion: effectiveReduceMotion
                            )
                        }
                    case .completion:
                        if selectedKind == .standing {
                            StandingMotionLabStage(
                                stage: .completion,
                                progress: progress,
                                reduceMotion: effectiveReduceMotion
                            )
                        } else {
                            CompletionVisualView(
                                kind: selectedKind,
                                progress: progress,
                                reduceMotion: effectiveReduceMotion
                            )
                        }
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 174)
            }
        }
    }

    private func controlSection<Content: View>(
        title: String,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(HealthFirstStyle.lavenderDark)
            content()
        }
    }

    private func previewCard<Content: View>(
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider()

            content()
                .padding(12)
        }
        .background(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(HealthFirstStyle.secondarySurface.opacity(0.72))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .strokeBorder(.primary.opacity(0.07))
        }
    }

    private var selectedMotionOption: MotionOption {
        Self.motionOptions.first { $0.motion == selectedMotion } ?? Self.motionOptions[0]
    }

    private func mascotPreviewProgress(at date: Date) -> Double {
        let duration: TimeInterval = selectedMotion == .agreeing ? 1.44 : 0.65
        guard duration > 0 else { return 1 }
        return min(1, max(0, date.timeIntervalSince(mascotReplayStartedAt) / duration))
    }

    private var effectiveReduceMotion: Bool {
        systemReduceMotion || reduceMotion
    }

    private var visualPreviewSubtitle: String {
        guard selectedKind == .standing else {
            return "\(selectedKind.displayName) · \(Int(progress * 100))%"
        }
        return "\(selectedKind.displayName) · \(standingElapsed.formatted(.number.precision(.fractionLength(1)))) 秒 · \(standingMilestone)"
    }

    private var standingElapsed: TimeInterval {
        let duration = visualStage == .guidance
            ? StandingGuideTimeline.duration
            : StandingCompletionTimeline.duration
        return min(max(progress, 0), 1) * duration
    }

    private var standingMilestone: String {
        switch visualStage {
        case .guidance:
            switch standingElapsed {
            case ..<StandingBeat.title.startSeconds:
                "检查装饰轨"
            case ..<StandingBeat.title.endSeconds:
                "标题条 → 车把"
            case ..<StandingBeat.backing.startSeconds:
                "车把已就位"
            case ..<StandingBeat.backing.endSeconds:
                "背板 → 货箱"
            case ..<StandingBeat.rails.startSeconds:
                "货箱已就位"
            case ..<StandingBeat.rails.endSeconds:
                "装饰轨 → 底盘"
            case ..<StandingBeat.ribbon.startSeconds:
                "底盘已就位"
            case ..<StandingBeat.ribbon.endSeconds:
                "织带捆扎"
            default:
                "扶住小推车"
            }

        case .completion:
            switch standingElapsed {
            case ..<0.16:
                "拿起完成牌"
            case ..<0.42:
                "放到车顶"
            case ..<0.52:
                "扶稳小车"
            case ..<0.78:
                "一次承重回弹"
            case ..<0.86:
                "轻微微笑"
            default:
                "完成静止"
            }
        }
    }

    private var visualProgressAccessibilityValue: String {
        guard selectedKind == .standing else {
            return "\(Int(progress * 100))%"
        }
        return "\(standingElapsed.formatted(.number.precision(.fractionLength(1)))) 秒，\(standingMilestone)"
    }

    private static let motionOptions: [MotionOption] = [
        MotionOption(.idle, "静候", "平时安静陪伴的默认状态。", "circle.dotted"),
        MotionOption(.entering, "第一次登场", "从边缘轻轻滑入，开始一次提醒。", "rectangle.portrait.and.arrow.right"),
        MotionOption(.agreeing, "收到同意", "正式纵切：从右侧接住工作牌，送进卷轴，再轻轻微笑。", "checkmark.seal"),
        MotionOption(.snoozing, "稍后再来", "正式协同动作待制作；当前先显示静态角色与可用灰盒。", "clock.arrow.circlepath"),
        MotionOption(.skipping, "本次跳过", "折叠姿势已接入；归档条与离场协同仍待正式制作。", "archivebox"),
        MotionOption(.ignored, "没有回应", "折叠姿势已接入；收书签动作仍待正式制作。", "bookmark"),
        MotionOption(.followUp, "再次提醒", "正式翻面返回动作待制作；当前保持中性静态姿势。", "exclamationmark.bubble"),
        MotionOption(.guidingEye, "陪伴护眼", "把视线交给远处的小光点。", "eye"),
        MotionOption(.guidingStanding, "陪伴站立", "拆框、小推车与正式抓取、搬运、扶车姿势已接入。", "figure.stand"),
        MotionOption(.guidingQuiet, "陪伴小动作", "正式三分之四转身与背面姿势已经接入。", "envelope"),
        MotionOption(.completed, "完成", "微笑并盖章，让结束有一点仪式感。", "checkmark.circle"),
        MotionOption(.serious, "认真模式", "全屏流程可用；角色铺工作垫的正式动作仍待制作。", "rectangle.inset.filled")
    ]
}

private enum VisualPreviewStage: String, CaseIterable, Identifiable {
    case guidance
    case completion

    var id: String { rawValue }

    var title: String {
        switch self {
        case .guidance: "陪伴分层"
        case .completion: "完成收尾"
        }
    }
}

private struct GuidanceChromePreview: View {
    let kind: ReminderKind
    let progress: Double
    let reduceMotion: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.white.opacity(0.88))
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(.primary.opacity(0.07))
                }

            GuidanceChromeView(
                kind: kind,
                progress: progress,
                reduceMotion: reduceMotion
            )

            HStack(spacing: 6) {
                Capsule()
                    .fill(HealthFirstStyle.orange.opacity(0.54))
                    .frame(width: 54, height: 4)
                Spacer()
                Text("安全操作层")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .frame(width: 222, height: 34)
            .background(.white.opacity(0.96), in: RoundedRectangle(cornerRadius: 12))
            .offset(x: 9, y: 92)
        }
        .frame(width: 420, height: 280)
        .scaleEffect(0.60)
        .frame(width: 252, height: 168)
        .clipped()
    }
}

/// The standing preview uses the same 420 x 280 geometry, trolley and
/// production character poses as the live reminder. Only the fixed safety
/// dock below is a non-interactive lab label.
private struct StandingMotionLabStage: View {
    let stage: VisualPreviewStage
    let progress: Double
    let reduceMotion: Bool

    private var normalizedProgress: Double {
        min(max(progress, 0), 1)
    }

    private var guidanceElapsed: TimeInterval {
        normalizedProgress * StandingGuideTimeline.duration
    }

    private var completionElapsed: TimeInterval {
        normalizedProgress * StandingCompletionTimeline.duration
    }

    private var completion: StandingCompletionSnapshot {
        StandingCompletionTimeline.snapshot(elapsed: completionElapsed)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.white.opacity(0.88))
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(.primary.opacity(0.07))
                }
                .frame(
                    width: StandingStageGeometry.size.width,
                    height: StandingStageGeometry.size.height
                )
                .zIndex(-1)

            assembly
                .zIndex(0)

            mascot
                .frame(
                    width: StandingStageGeometry.roleSlot.width,
                    height: StandingStageGeometry.roleSlot.height
                )
                .position(
                    x: StandingStageGeometry.roleSlot.midX,
                    y: StandingStageGeometry.roleSlot.midY
                )
                .zIndex(4)

            if stage == .guidance {
                standingSafetyDock
                    .position(x: 135, y: 232)
                    .zIndex(20)
            }
        }
        .frame(
            width: StandingStageGeometry.size.width,
            height: StandingStageGeometry.size.height,
            alignment: .topLeading
        )
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .scaleEffect(0.60)
        .frame(width: 252, height: 168)
        .clipped()
    }

    @ViewBuilder
    private var assembly: some View {
        switch stage {
        case .guidance:
            StandingAssemblyView(
                elapsed: guidanceElapsed,
                reduceMotion: reduceMotion
            )

        case .completion:
            StandingAssemblyView(
                snapshot: .completed,
                completion: completion,
                reduceMotion: reduceMotion
            )
        }
    }

    @ViewBuilder
    private var mascot: some View {
        switch stage {
        case .guidance:
            ProductionMascotView(
                motion: .guidingStanding,
                progress: normalizedProgress,
                reduceMotion: reduceMotion,
                acceptanceSide: .viewerLeft
            )

        case .completion:
            let presentation = completionMascotPresentation
            ProductionMascotView(
                expression: presentation.smiles ? .subtleSmile : .neutral,
                motion: .guidingStanding,
                progress: 1,
                actionProgress: presentation.actionProgress,
                reduceMotion: reduceMotion,
                acceptanceSide: .viewerLeft,
                standingBeat: presentation.beat
            )
        }
    }

    /// Match the live reminder exactly: the completion-specific lift starts
    /// from the existing cart grip and returns to it before the smile.
    private var completionMascotPresentation: StandingCompletionMascotPresentation {
        if completionElapsed < 0.50 {
            return StandingCompletionMascotPresentation(
                beat: .completionLift,
                actionProgress: min(max(completionElapsed / 0.50, 0), 1),
                smiles: false
            )
        }

        return StandingCompletionMascotPresentation(
            beat: .cartHoldSmile,
            actionProgress: completion.smileProgress,
            smiles: true
        )
    }

    private var standingSafetyDock: some View {
        VStack(alignment: .leading, spacing: 6) {
            ProgressView(value: normalizedProgress)
                .tint(HealthFirstStyle.orange)

            HStack(spacing: 8) {
                Text("还剩 \(max(0, Int(ceil(60 - guidanceElapsed)))) 秒")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                Spacer(minLength: 4)
                Text("提前结束")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(width: 222, height: 54)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(HealthFirstStyle.secondarySurface.opacity(0.98))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(.primary.opacity(0.09))
        }
    }
}

private struct StandingCompletionMascotPresentation {
    let beat: StandingMascotBeat
    let actionProgress: Double
    let smiles: Bool
}

private struct MotionOption: Identifiable {
    let motion: MascotMotion
    let title: String
    let note: String
    let systemImage: String

    var id: MascotMotion { motion }

    init(_ motion: MascotMotion, _ title: String, _ note: String, _ systemImage: String) {
        self.motion = motion
        self.title = title
        self.note = note
        self.systemImage = systemImage
    }
}
#endif
