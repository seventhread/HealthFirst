import HealthFirstCore
import SwiftUI

@MainActor
struct ReminderCardView: View {
    private static let acceptanceDuration: TimeInterval = 1.44

    @ObservedObject var model: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @AccessibilityFocusState private var statusFocused: Bool
    @FocusState private var primaryActionFocused: Bool

    var body: some View {
        ZStack {
            Color.clear
                .frame(width: 396, height: 256)
                .healthFirstCard(chromeOpacity: cardChromeOpacity)
                .allowsHitTesting(false)
                .accessibilityHidden(true)

            guidanceChromeLayer

            cardContentLayer

            acceptanceWorkCardLayer
        }
        .frame(width: 420, height: 280)
        .onHover(perform: model.setPanelHovering)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: model.receipt)
        .animation(
            reduceMotion ? .easeOut(duration: 0.18) : .linear(duration: 0.25),
            value: cardChromeOpacity
        )
        .task(id: focusGeneration) {
            // A new hosting view starts with the latest state already set, so
            // relying only on `onChange` can miss its initial focus target.
            await Task.yield()
            statusFocused = true
            primaryActionFocused = shouldFocusPrimaryAction
        }
        .accessibilityElement(children: .contain)
    }

    private var contentSpacing: CGFloat {
        model.isGuiding || model.receipt != nil ? 12 : 18
    }

    private var mascotSize: CGSize {
        return CGSize(width: 106, height: 124)
    }

    private var mascotLayer: some View {
        TimelineView(
            .animation(
                minimumInterval: reduceMotion ? 0.1 : 1.0 / 30.0,
                paused: !mascotTimelineActive
            )
        ) { context in
            // A paused Timeline may retain an old context date. Parent model
            // ticks still refresh `model.now`, so inactive/sleep-jumped stages
            // render their current deterministic snapshot instead of a stale
            // pre-milestone pose.
            let presentationDate = mascotTimelineActive ? context.date : model.now
            let presentation = mascotPresentation(at: presentationDate)

            ProductionMascotView(
                expression: presentation.expression,
                motion: presentation.motion,
                progress: presentation.progress,
                actionProgress: presentation.actionProgress,
                reduceMotion: reduceMotion,
                acceptanceSide: presentation.acceptanceSide,
                standingBeat: presentation.standingBeat
            )
            .frame(width: mascotSize.width, height: mascotSize.height)
            .opacity(mascotOpacity(at: presentationDate))
        }
        .frame(width: mascotSize.width, height: mascotSize.height)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var cardContentLayer: some View {
        if let reminder = model.activeReminder,
           reminder.kind == .standing,
           case .guided = reminder.state,
           model.exitAnimation == nil,
           model.receipt == nil {
            standingGuidanceStage(for: reminder)
        } else if model.receipt == .completed,
                  model.activeReminder?.kind == .standing,
                  model.exitAnimation == nil {
            standingCompletionStage
        } else {
            compactContentRow
        }
    }

    @ViewBuilder
    private var compactContentRow: some View {
        HStack(alignment: .center, spacing: contentSpacing) {
            if usesStandingPromptLayout {
                cardStateContent
                    .frame(
                        maxWidth: .infinity,
                        maxHeight: .infinity,
                        alignment: .leading
                    )
                mascotLayer
            } else {
                mascotLayer
                cardStateContent
                    .frame(
                        maxWidth: .infinity,
                        maxHeight: .infinity,
                        alignment: .leading
                    )
            }
        }
        .frame(width: 352, height: 212)
    }

    @ViewBuilder
    private var cardStateContent: some View {
        if let exitAnimation = model.exitAnimation {
            exitView(exitAnimation)
        } else if let receipt = model.receipt {
            receiptView(receipt)
        } else if let reminder = model.activeReminder {
            content(for: reminder)
        } else {
            Text("提醒已经收好。")
                .foregroundStyle(.secondary)
        }
    }

    private var usesStandingPromptLayout: Bool {
        guard model.exitAnimation == nil,
              model.receipt == nil,
              let reminder = model.activeReminder,
              reminder.kind == .standing else {
            return false
        }

        switch reminder.state {
        case .firstPresented, .followUpPresented, .pendingInMenuBar, .seriousPresented:
            return true
        default:
            return false
        }
    }

    /// Only the decorative card material fades. The fixed safety dock remains
    /// fully opaque and interactive above it.
    private var cardChromeOpacity: Double {
        guard !reduceTransparency,
              let reminder = model.activeReminder,
              case .guided = reminder.state else { return 1 }

        let progress = model.guidanceProgress(for: reminder)
        switch reminder.kind {
        case .eye:
            return 1 - 0.82 * motionPhase(
                startSeconds: 0.56,
                endSeconds: 1.10,
                totalSeconds: 20,
                progress: progress
            )
        case .standing:
            let title = motionPhase(
                startSeconds: 8,
                endSeconds: 8.6,
                totalSeconds: 60,
                progress: progress
            )
            let backing = motionPhase(
                startSeconds: 22,
                endSeconds: 22.6,
                totalSeconds: 60,
                progress: progress
            )
            let rails = motionPhase(
                startSeconds: 38,
                endSeconds: 38.6,
                totalSeconds: 60,
                progress: progress
            )
            let ribbon = motionPhase(
                startSeconds: 52,
                endSeconds: 52.6,
                totalSeconds: 60,
                progress: progress
            )
            return 1 - 0.16 * title - 0.16 * backing - 0.16 * rails - 0.20 * ribbon
        case .quietPractice:
            return 1 - 0.62 * motionPhase(
                startSeconds: 0.56,
                endSeconds: 1.46,
                totalSeconds: 30,
                progress: progress
            )
        }
    }

    @ViewBuilder
    private var guidanceChromeLayer: some View {
        if let reminder = model.activeReminder,
           reminder.kind != .standing,
           case .guided(let startedAt, let endsAt) = reminder.state {
            TimelineView(
                .animation(
                    minimumInterval: reduceMotion ? 0.1 : 1.0 / 30.0,
                    paused: !guidanceChromeTimelineActive(
                        kind: reminder.kind,
                        startedAt: startedAt
                    )
                )
            ) { context in
                GuidanceChromeView(
                    kind: reminder.kind,
                    progress: timelineProgress(
                        startedAt: startedAt,
                        endsAt: endsAt,
                        at: context.date
                    ),
                    reduceMotion: reduceMotion
                )
            }
        }
    }

    /// Standing owns the full 420 x 280 presentation stage. The decorative
    /// source fragments and the one shared trolley stay behind both the
    /// character and the real, interactive safety dock.
    @ViewBuilder
    private func standingGuidanceStage(for reminder: ReminderInstance) -> some View {
        if case .guided(let startedAt, _) = reminder.state {
            ZStack(alignment: .topLeading) {
                standingAssemblyLayer(startedAt: startedAt)
                .zIndex(0)

                mascotLayer
                    .frame(
                        width: StandingStageGeometry.roleSlot.width,
                        height: StandingStageGeometry.roleSlot.height
                    )
                    .position(
                        x: StandingStageGeometry.roleSlot.midX,
                        y: StandingStageGeometry.roleSlot.midY
                    )
                    .zIndex(4)

                // Keep focusable controls outside the 30 fps decorative
                // Timeline. Their identity and hit target remain stable while
                // the character and assembly are sampled independently.
                guidanceView(for: reminder)
                    .frame(width: 222, height: 232, alignment: .topLeading)
                    .position(x: 135, y: 140)
                    .zIndex(20)
            }
            .frame(
                width: StandingStageGeometry.size.width,
                height: StandingStageGeometry.size.height,
                alignment: .topLeading
            )
        }
    }

    @ViewBuilder
    private func standingAssemblyLayer(startedAt: Date) -> some View {
        if guidanceChromeTimelineActive(kind: .standing, startedAt: startedAt) {
            TimelineView(
                .animation(minimumInterval: reduceMotion ? 0.1 : 1.0 / 30.0)
            ) { context in
                StandingAssemblyView(
                    snapshot: StandingGuideTimeline.snapshot(
                        elapsed: max(0, context.date.timeIntervalSince(startedAt))
                    ),
                    reduceMotion: reduceMotion
                )
            }
        } else {
            StandingAssemblyView(
                snapshot: StandingGuideTimeline.snapshot(
                    elapsed: max(0, model.now.timeIntervalSince(startedAt))
                ),
                reduceMotion: reduceMotion
            )
        }
    }

    /// Completion keeps the exact trolley assembled during guidance. Only a
    /// completion card and its three-point load response are added; there is
    /// no second cart implementation to snap into place at sixty seconds.
    private var standingCompletionStage: some View {
        ZStack(alignment: .topLeading) {
            TimelineView(
                .animation(
                    minimumInterval: reduceMotion ? 0.1 : 1.0 / 30.0,
                    paused: receiptElapsed >= StandingCompletionTimeline.duration
                )
            ) { context in
                StandingAssemblyView(
                    snapshot: .completed,
                    completion: StandingCompletionTimeline.snapshot(
                        elapsed: standingCompletionElapsed(at: context.date)
                    ),
                    reduceMotion: reduceMotion
                )
            }
            .zIndex(0)

            mascotLayer
                .frame(
                    width: StandingStageGeometry.roleSlot.width,
                    height: StandingStageGeometry.roleSlot.height
                )
                .position(
                    x: StandingStageGeometry.roleSlot.midX,
                    y: StandingStageGeometry.roleSlot.midY
                )
                .zIndex(4)

            // The receipt button must not be regenerated by the completion
            // display Timeline; keyboard and VoiceOver focus stay attached.
            receiptView(.completed)
                .frame(width: 222, height: 126, alignment: .topLeading)
                .position(x: 135, y: 91)
                .zIndex(20)
        }
        .frame(
            width: StandingStageGeometry.size.width,
            height: StandingStageGeometry.size.height,
            alignment: .topLeading
        )
    }

    /// A visual echo of the accepted primary action. It is deliberately
    /// clocked from the already-created guided state, and never participates
    /// in hit testing, focus, or reminder-state transitions.
    @ViewBuilder
    private var acceptanceWorkCardLayer: some View {
        if let reminder = model.activeReminder,
           case .guided(let startedAt, _) = reminder.state {
            TimelineView(
                .animation(
                    minimumInterval: reduceMotion ? 0.1 : 1.0 / 30.0,
                    paused: model.now.timeIntervalSince(startedAt) >= 0.56
                )
            ) { context in
                AcceptanceWorkCardOverlay(
                    elapsed: max(0, context.date.timeIntervalSince(startedAt)),
                    direction: reminder.kind == .standing ? .viewerLeft : .viewerRight,
                    reduceMotion: reduceMotion
                )
            }
            .frame(width: 420, height: 280)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }

    @ViewBuilder
    private func content(for reminder: ReminderInstance) -> some View {
        switch reminder.state {
        case .firstPresented:
            promptView(for: reminder, stage: .first)
        case .followUpPresented:
            promptView(for: reminder, stage: .followUp)
        case .pendingInMenuBar:
            promptView(for: reminder, stage: .followUp, fromMenuBar: true)
        case .seriousPresented:
            seriousPrompt(for: reminder)
        case .guided:
            guidanceView(for: reminder)
        case .retryPending, .snoozed:
            Text("已经安排好下一次出现。")
                .foregroundStyle(.secondary)
        case .completed:
            receiptView(.completed)
        case .skipped:
            receiptView(.skipped)
        case .emergencySkip:
            receiptView(.emergencySkipped)
        case .scheduled:
            Text("提醒正在路上。")
                .foregroundStyle(.secondary)
        }
    }

    private func promptView(
        for reminder: ReminderInstance,
        stage: ReminderPresentationStage,
        fromMenuBar: Bool = false
    ) -> some View {
        let snoozeDelay: TimeInterval = stage == .first ? 3 * 60 : 10 * 60
        let copy = ReminderCopy.prompt(
            for: reminder.kind,
            stage: stage,
            tone: model.copyTone,
            reminderID: reminder.id,
            snoozeDelay: snoozeDelay
        )

        return VStack(alignment: .leading, spacing: 9) {
            reminderHeader(reminder.kind, badge: copy.eyebrow)

            Text(copy.title)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(HealthFirstStyle.ink)
                .fixedSize(horizontal: false, vertical: true)

            Text(fromMenuBar ? "我把这张小纸条先夹在菜单栏了。\(copy.message)" : copy.message)
                .font(.system(size: 12.5))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Button(copy.actions.start) {
                model.startActiveReminder()
            }
            .buttonStyle(PrimaryActionButtonStyle())
            .keyboardShortcut(.defaultAction)
            .focused($primaryActionFocused)

            HStack(spacing: 8) {
                if !fromMenuBar {
                    Button(copy.actions.snooze) {
                        model.snoozeActiveReminder()
                    }
                }
                Button(copy.actions.skip) {
                    model.skipActiveReminder()
                }
            }
            .buttonStyle(.borderless)
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
        }
    }

    private func seriousPrompt(for reminder: ReminderInstance) -> some View {
        let copy = ReminderCopy.prompt(
            for: reminder.kind,
            stage: .serious,
            tone: model.copyTone,
            reminderID: reminder.id,
            snoozeDelay: 10 * 60
        )

        return VStack(alignment: .leading, spacing: 10) {
            reminderHeader(reminder.kind, badge: copy.eyebrow)
            Text(copy.title)
                .font(.system(size: 16, weight: .bold, design: .rounded))
            Text(copy.message)
                .font(.system(size: 12.5))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Button(copy.actions.start) {
                model.startActiveReminder()
            }
            .buttonStyle(PrimaryActionButtonStyle())
            .keyboardShortcut(.defaultAction)
            .focused($primaryActionFocused)

        }
    }

    private func guidanceView(for reminder: ReminderInstance) -> some View {
        let remaining = model.remainingSeconds(for: reminder)
        let progress = model.guidanceProgress(for: reminder)
        let actions = ReminderCopy.actionLabels(
            for: reminder.kind,
            tone: model.copyTone
        )
        let headerOpacity = guidanceHeaderOpacity(
            for: reminder.kind,
            progress: progress
        )

        return VStack(alignment: .leading, spacing: 8) {
            reminderHeader(reminder.kind, badge: "陪你一会儿")
                .opacity(max(0.01, headerOpacity))
                .accessibilityLabel("\(reminder.kind.displayName)提醒，陪伴进行中")
                .accessibilityHidden(false)

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 7) {
                if reminder.kind != .eye {
                    ProgressView(value: progress)
                        .tint(HealthFirstStyle.orange)
                        .accessibilityLabel("练习进度")
                        .accessibilityValue("还剩 \(remaining) 秒")
                }

                HStack(spacing: 8) {
                    if reminder.kind == .eye {
                        Text("看远处，我结束时回来")
                            .font(.system(size: 12, weight: .medium))
                            .accessibilityValue("还剩 \(remaining) 秒")
                    } else {
                        Text("还剩 \(remaining) 秒")
                            .font(.system(.title3, design: .rounded, weight: .semibold))
                            .monospacedDigit()
                    }
                    Spacer(minLength: 4)
                    Button(actions.endEarly) {
                        model.endGuidanceEarly()
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(width: 222)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        reduceTransparency
                            ? HealthFirstStyle.surface
                            : HealthFirstStyle.secondarySurface.opacity(0.94)
                    )
            )
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(.primary.opacity(0.08))
            }
            .zIndex(10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .animation(
            reduceMotion ? .easeOut(duration: 0.18) : .linear(duration: 0.25),
            value: headerOpacity
        )
    }

    private func exitView(_ exit: PanelExitAnimation) -> some View {
        let elapsed = model.now.timeIntervalSince(
            model.exitAnimationStartedAt ?? model.now
        )
        let progress = min(1, max(0, elapsed / 0.4))
        let fold = reduceMotion ? 1.0 : progress

        return VStack(alignment: .leading, spacing: 12) {
            reminderHeader(exit.kind, badge: "先收好")

            ZStack(alignment: .bottomTrailing) {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(HealthFirstStyle.lavender.opacity(0.2))
                    .overlay {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(HealthFirstStyle.lavenderDark.opacity(0.16))
                    }
                    .frame(width: 150, height: 58)
                    .scaleEffect(
                        x: 1 - 0.5 * fold,
                        y: 1 - 0.58 * fold,
                        anchor: .bottomTrailing
                    )
                    .opacity(1 - 0.2 * fold)

                Image(systemName: "bookmark.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(HealthFirstStyle.orange)
                    .scaleEffect(0.72 + 0.28 * fold)
                    .opacity(fold)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .allowsHitTesting(false)
            .accessibilityHidden(true)

            Text(
                exit.isRetry
                    ? "先夹在这里，过一会儿再见。"
                    : "我把它夹回菜单栏了。"
            )
            .font(.system(size: 12.5, weight: .medium))
            .foregroundStyle(.secondary)
        }
    }

    private var mascotTimelineActive: Bool {
        if let startedAt = model.exitAnimationStartedAt {
            return model.now.timeIntervalSince(startedAt) < 0.4
        }

        if let startedAt = model.receiptStartedAt,
           model.receipt?.isPositive == true {
            return model.now.timeIntervalSince(startedAt) < 1.1
        }

        guard let reminder = model.activeReminder else { return false }
        switch reminder.state {
        case .firstPresented:
            return panelElapsed < 0.65
        case .guided(let startedAt, _):
            let elapsed = model.now.timeIntervalSince(startedAt)
            switch reminder.kind {
            case .eye:
                return elapsed < 1.10
            case .standing:
                return elapsed < Self.acceptanceDuration
                    || elapsed < Self.acceptanceDuration + 0.30
                    || standingVisualTimelineActive(elapsed: elapsed)
            case .quietPractice:
                return elapsed < 0.82
            }
        default:
            return false
        }
    }

    private func mascotPresentation(at date: Date) -> MascotPresentation {
        if let startedAt = model.exitAnimationStartedAt {
            return MascotPresentation(
                motion: .ignored,
                progress: normalized(date.timeIntervalSince(startedAt) / 0.4)
            )
        }

        if let receipt = model.receipt,
           let startedAt = model.receiptStartedAt {
            let elapsed = max(0, date.timeIntervalSince(startedAt))

            if receipt == .completed,
               model.activeReminder?.kind == .standing {
                let completion = StandingCompletionTimeline.snapshot(elapsed: elapsed)
                if elapsed < 0.50 {
                    return MascotPresentation(
                        motion: .guidingStanding,
                        progress: 1,
                        actionProgress: normalized(elapsed / 0.50),
                        acceptanceSide: .viewerLeft,
                        standingBeat: .completionLift
                    )
                }
                return MascotPresentation(
                    expression: .subtleSmile,
                    motion: .guidingStanding,
                    progress: 1,
                    actionProgress: completion.smileProgress,
                    acceptanceSide: .viewerLeft,
                    standingBeat: .cartHoldSmile
                )
            }

            let motion: MascotMotion
            let duration: TimeInterval

            switch receipt {
            case .completed:
                motion = elapsed < 1.1 ? .completed : .idle
                duration = 0.9
            case .snoozed:
                motion = .snoozing
                duration = 0.6
            case .skipped, .endedEarly:
                motion = .skipping
                duration = 0.5
            case .emergencySkipped:
                motion = .idle
                duration = 0.2
            }

            return MascotPresentation(
                expression: receipt.isPositive && elapsed < 1.1 ? .subtleSmile : .neutral,
                motion: motion,
                progress: normalized(elapsed / duration)
            )
        }

        guard let reminder = model.activeReminder else {
            return MascotPresentation(motion: .idle, progress: 1)
        }

        switch reminder.state {
        case .firstPresented:
            let elapsed = max(0, date.timeIntervalSince(model.panelPresentationStartedAt ?? date))
            if elapsed < 0.65 {
                return MascotPresentation(
                    motion: .entering,
                    progress: normalized(elapsed / 0.65),
                    actionProgress: normalized(elapsed / 0.65)
                )
            }
            return MascotPresentation(motion: .idle, progress: 1)

        case .followUpPresented, .pendingInMenuBar:
            return MascotPresentation(motion: .followUp, progress: 1)

        case .seriousPresented:
            return MascotPresentation(motion: .serious, progress: 1)

        case .guided(let startedAt, let endsAt):
            let elapsed = max(0, date.timeIntervalSince(startedAt))
            if elapsed < 0.56 {
                let actionProgress = normalized(elapsed / Self.acceptanceDuration)
                return MascotPresentation(
                    motion: .agreeing,
                    progress: actionProgress,
                    actionProgress: actionProgress,
                    acceptanceSide: reminder.kind == .standing ? .viewerLeft : .viewerRight
                )
            }

            switch reminder.kind {
            case .eye:
                return MascotPresentation(
                    motion: .guidingEye,
                    progress: timelineProgress(
                        startedAt: startedAt,
                        endsAt: endsAt,
                        at: date
                    ),
                    actionProgress: normalized((elapsed - 0.56) / 0.32)
                )

            case .standing:
                if elapsed < Self.acceptanceDuration {
                    let actionProgress = normalized(elapsed / Self.acceptanceDuration)
                    return MascotPresentation(
                        motion: .agreeing,
                        progress: actionProgress,
                        actionProgress: actionProgress,
                        acceptanceSide: .viewerLeft
                    )
                }

                let standing = standingMascotPresentation(elapsed: elapsed)
                return MascotPresentation(
                    motion: .guidingStanding,
                    progress: timelineProgress(
                        startedAt: startedAt,
                        endsAt: endsAt,
                        at: date
                    ),
                    actionProgress: standing.progress,
                    acceptanceSide: .viewerLeft,
                    standingBeat: standing.beat
                )

            case .quietPractice:
                return MascotPresentation(
                    motion: .guidingQuiet,
                    progress: timelineProgress(
                        startedAt: startedAt,
                        endsAt: endsAt,
                        at: date
                    ),
                    actionProgress: normalized((elapsed - 0.56) / 0.26)
                )
            }

        case .retryPending:
            return MascotPresentation(motion: .ignored, progress: 1)
        case .completed:
            return MascotPresentation(expression: .subtleSmile, motion: .completed, progress: 1)
        case .snoozed:
            return MascotPresentation(motion: .snoozing, progress: 1)
        case .skipped:
            return MascotPresentation(motion: .skipping, progress: 1)
        case .scheduled, .emergencySkip:
            return MascotPresentation(motion: .idle, progress: 1)
        }
    }

    private func standingMascotPresentation(
        elapsed: TimeInterval
    ) -> (beat: StandingMascotBeat, progress: Double) {
        if elapsed < Self.acceptanceDuration + 0.30 {
            let settle = normalized(
                (elapsed - Self.acceptanceDuration) / 0.30
            )
            return (.inspect, min(0.5, settle * 0.5))
        }

        if elapsed < StandingBeat.title.startSeconds {
            // The inspect pose is already settled once the acceptance ritual
            // has returned to neutral; 0.5 holds the short-beat key pose.
            return (.inspect, 0.5)
        }

        let snapshot = StandingGuideTimeline.snapshot(elapsed: elapsed)
        if let beat = snapshot.activeBeat {
            let localProgress = normalized(
                (elapsed - beat.startSeconds) / StandingBeat.duration
            )
            switch beat {
            case .title:
                return (.lift, localProgress)
            case .backing:
                return (.carry, localProgress)
            case .rails:
                return (.carry, localProgress)
            case .ribbon:
                return (.cartHold, localProgress)
            }
        }

        return elapsed >= StandingBeat.ribbon.endSeconds
            ? (.cartHold, 1)
            : (.idle, 1)
    }

    private var receiptElapsed: TimeInterval {
        guard let startedAt = model.receiptStartedAt else { return 0 }
        return max(0, model.now.timeIntervalSince(startedAt))
    }

    private func standingCompletionElapsed(at date: Date) -> TimeInterval {
        guard let startedAt = model.receiptStartedAt else {
            return StandingCompletionTimeline.duration
        }
        return max(0, date.timeIntervalSince(startedAt))
    }

    private func mascotOpacity(at date: Date) -> Double {
        guard let reminder = model.activeReminder,
              reminder.kind == .eye,
              case .guided(let startedAt, _) = reminder.state else {
            return 1
        }
        if reduceMotion {
            return 1 - normalized((date.timeIntervalSince(startedAt) - 0.92) / 0.18)
        }
        let elapsed = date.timeIntervalSince(startedAt)
        return 1 - normalized((elapsed - 0.82) / 0.28)
    }

    private var panelElapsed: TimeInterval {
        max(
            0,
            model.now.timeIntervalSince(
                model.panelPresentationStartedAt ?? model.now
            )
        )
    }

    private func normalized(_ value: Double) -> Double {
        guard value.isFinite else { return 0 }
        return min(1, max(0, value))
    }

    private func timelineProgress(
        startedAt: Date,
        endsAt: Date,
        at date: Date
    ) -> Double {
        let duration = endsAt.timeIntervalSince(startedAt)
        guard duration > 0 else { return 1 }
        return normalized(date.timeIntervalSince(startedAt) / duration)
    }

    private func motionPhase(
        startSeconds: Double,
        endSeconds: Double,
        totalSeconds: Double,
        progress: Double
    ) -> Double {
        guard totalSeconds > 0, endSeconds > startSeconds else { return 1 }
        let elapsed = normalized(progress) * totalSeconds
        return normalized((elapsed - startSeconds) / (endSeconds - startSeconds))
    }

    private func guidanceHeaderOpacity(
        for kind: ReminderKind,
        progress: Double
    ) -> Double {
        switch kind {
        case .eye:
            return 1 - motionPhase(
                startSeconds: 0.56,
                endSeconds: 1.10,
                totalSeconds: 20,
                progress: progress
            )
        case .standing:
            return 1 - motionPhase(
                startSeconds: 8,
                endSeconds: 8.6,
                totalSeconds: 60,
                progress: progress
            )
        case .quietPractice:
            return 1 - motionPhase(
                startSeconds: 0.56,
                endSeconds: 0.81,
                totalSeconds: 30,
                progress: progress
            )
        }
    }

    private func guidanceChromeTimelineActive(
        kind: ReminderKind,
        startedAt: Date
    ) -> Bool {
        let elapsed = max(0, model.now.timeIntervalSince(startedAt))
        switch kind {
        case .eye:
            return elapsed < 1.10
        case .quietPractice:
            return elapsed < 1.46
        case .standing:
            return standingVisualTimelineActive(elapsed: elapsed)
        }
    }

    private func standingVisualTimelineActive(elapsed: TimeInterval) -> Bool {
        StandingBeat.allCases.contains { beat in
            elapsed >= beat.startSeconds - 0.30
                && elapsed < beat.endSeconds
        }
    }

    private var focusGeneration: TimeInterval {
        let date = model.receiptStartedAt
            ?? model.exitAnimationStartedAt
            ?? model.panelPresentationStartedAt
            ?? .distantPast
        return date.timeIntervalSinceReferenceDate
    }

    private var shouldFocusPrimaryAction: Bool {
        if model.receipt != nil { return true }
        guard let reminder = model.activeReminder else { return false }
        switch reminder.state {
        case .firstPresented, .followUpPresented, .pendingInMenuBar, .seriousPresented:
            return true
        default:
            return false
        }
    }

    private func receiptView(_ receipt: PanelReceipt) -> some View {
        let copy = receiptCopy(for: receipt)

        return VStack(alignment: .leading, spacing: 10) {
            Text(copy.title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(receipt.isPositive ? HealthFirstStyle.orange : .secondary)
                .accessibilityFocused($statusFocused)

            if receipt == .completed,
               model.activeReminder?.kind != .standing {
                completionVisual(for: model.activeReminder?.kind ?? .eye)
                    .scaleEffect(0.86)
                    .frame(width: 238, height: 70)
                    .clipped()
            }

            Text(copy.message)
                .font(.system(size: 17, weight: .semibold))
                .fixedSize(horizontal: false, vertical: true)
            Button(copy.dismissButton) {
                model.dismissReceipt()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .focused($primaryActionFocused)
        }
        .accessibilityElement(children: .contain)
    }

    private func completionVisual(for kind: ReminderKind) -> some View {
        let duration = completionDuration(for: kind)
        let isSettled = receiptElapsed >= duration

        return TimelineView(
            .animation(
                minimumInterval: reduceMotion ? 0.1 : 1.0 / 30.0,
                paused: isSettled
            )
        ) { context in
            CompletionVisualView(
                kind: kind,
                progress: completionProgress(
                    at: isSettled ? model.now : context.date,
                    duration: duration
                ),
                reduceMotion: reduceMotion
            )
        }
    }

    private func completionProgress(
        at date: Date,
        duration: TimeInterval
    ) -> Double {
        guard let startedAt = model.receiptStartedAt, duration > 0 else { return 1 }
        return normalized(date.timeIntervalSince(startedAt) / duration)
    }

    private func completionDuration(for kind: ReminderKind) -> TimeInterval {
        switch kind {
        case .eye: 0.85
        case .standing: 1.05
        case .quietPractice: 1.0
        }
    }

    private func reminderHeader(_ kind: ReminderKind, badge: String?) -> some View {
        HStack(spacing: 8) {
            Image(systemName: kind.symbolName)
                .foregroundStyle(HealthFirstStyle.orange)
            Text("\(kind.displayName)提醒")
                .font(.system(size: 13, weight: .semibold))
            if let badge {
                Text(badge)
                    .font(.system(size: 10, weight: .semibold))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(HealthFirstStyle.lavender.opacity(0.25), in: Capsule())
            }
        }
        .foregroundStyle(.secondary)
        .accessibilityFocused($statusFocused)
        .accessibilityElement(children: .combine)
    }

    private func receiptCopy(for receipt: PanelReceipt) -> ReminderReceiptCopy {
        let kind = model.activeReminder?.kind ?? .eye
        return switch receipt {
        case .completed:
            ReminderCopy.receipt(for: kind, outcome: .completed, tone: model.copyTone)
        case .snoozed(let minutes):
            ReminderCopy.receipt(
                for: kind,
                outcome: .snoozed(delay: TimeInterval(minutes * 60)),
                tone: model.copyTone
            )
        case .skipped:
            ReminderCopy.receipt(for: kind, outcome: .skipped, tone: model.copyTone)
        case .endedEarly:
            ReminderReceiptCopy(
                title: "今天先到这里",
                message: "提前收工也算动过了。",
                dismissButton: "好"
            )
        case .emergencySkipped:
            ReminderReceiptCopy(
                title: "认真模式已退出",
                message: "先忙你的，我把工作台收好。",
                dismissButton: "好"
            )
        }
    }

}

private struct MascotPresentation {
    var expression: MascotExpression = .neutral
    let motion: MascotMotion
    let progress: Double
    var actionProgress: Double? = nil
    var acceptanceSide: AcceptanceSide = .viewerRight
    var standingBeat: StandingMascotBeat? = nil
}

/// The accepted button briefly becomes a small, blank work card. Coordinates
/// are intentionally fixed in the reminder's 420 x 280 presentation stage so
/// the card begins where the primary button was, reaches the selected
/// directional clamp, and finally disappears into the body reel. The mascot
/// artwork is never mirrored because its permanent orange reel is asymmetric.
private struct AcceptanceWorkCardOverlay: View {
    let elapsed: TimeInterval
    let direction: AcceptanceSide
    let reduceMotion: Bool

    private var buttonPoint: CGPoint {
        switch direction {
        case .viewerRight:
            CGPoint(x: 276, y: 169)
        case .viewerLeft:
            CGPoint(x: 152, y: 169)
        }
    }

    private var catchPoint: CGPoint {
        switch direction {
        case .viewerRight:
            CGPoint(x: 133, y: 148)
        case .viewerLeft:
            StandingStageGeometry.middleHandPoint
        }
    }

    private var reelPoint: CGPoint {
        switch direction {
        case .viewerRight:
            CGPoint(x: 105, y: 157)
        case .viewerLeft:
            CGPoint(x: 350, y: 157)
        }
    }

    var body: some View {
        workCard
            .frame(width: cardSize.width, height: cardSize.height)
            .rotationEffect(.degrees(rotation))
            .position(position)
            .opacity(opacity)
    }

    private var workCard: some View {
        RoundedRectangle(cornerRadius: 5, style: .continuous)
            .fill(HealthFirstStyle.lavender.opacity(0.54))
            .overlay {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .stroke(HealthFirstStyle.lavenderDark.opacity(0.28), lineWidth: 1)
            }
            .overlay(alignment: .bottomTrailing) {
                Capsule()
                    .fill(HealthFirstStyle.orange.opacity(0.9))
                    .frame(width: 8, height: 3)
                    .padding(.trailing, 4)
                    .padding(.bottom, 3)
            }
            .shadow(color: .black.opacity(reduceMotion ? 0 : 0.08), radius: 3, y: 1)
    }

    private var position: CGPoint {
        guard !reduceMotion else { return reelPoint }

        if elapsed < 0.26 {
            let amount = eased(phase(from: 0.04, to: 0.26))
            return CGPoint(
                x: interpolateCGFloat(buttonPoint.x, catchPoint.x, amount),
                y: interpolateCGFloat(buttonPoint.y, catchPoint.y, amount)
                    - CGFloat(15 * sin(amount * .pi))
            )
        }

        let amount = eased(phase(from: 0.26, to: 0.46))
        return CGPoint(
            x: interpolateCGFloat(catchPoint.x, reelPoint.x, amount),
            y: interpolateCGFloat(catchPoint.y, reelPoint.y, amount)
                - CGFloat(4 * sin(amount * .pi))
        )
    }

    private var cardSize: CGSize {
        guard !reduceMotion else { return CGSize(width: 38, height: 22) }

        if elapsed < 0.26 {
            let amount = eased(phase(from: 0.04, to: 0.26))
            return CGSize(
                width: interpolateCGFloat(72, 42, amount),
                height: interpolateCGFloat(30, 24, amount)
            )
        }

        let amount = eased(phase(from: 0.26, to: 0.50))
        return CGSize(
            width: interpolateCGFloat(42, 18, amount),
            height: interpolateCGFloat(24, 10, amount)
        )
    }

    private var rotation: Double {
        guard !reduceMotion else { return 0 }
        if elapsed < 0.26 {
            return interpolate(0, -8, eased(phase(from: 0.04, to: 0.26)))
        }
        return interpolate(-8, 12, eased(phase(from: 0.26, to: 0.50)))
    }

    private var opacity: Double {
        if reduceMotion {
            let fadeIn = phase(from: 0.08, to: 0.16)
            let fadeOut = phase(from: 0.34, to: 0.50)
            return fadeIn * (1 - fadeOut)
        }
        return 1 - phase(from: 0.44, to: 0.56)
    }

    private func phase(from start: Double, to end: Double) -> Double {
        guard end > start else { return elapsed >= end ? 1 : 0 }
        return min(max((elapsed - start) / (end - start), 0), 1)
    }

    private func eased(_ value: Double) -> Double {
        value * value * (3 - 2 * value)
    }

    private func interpolateCGFloat(
        _ start: CGFloat,
        _ end: CGFloat,
        _ amount: Double
    ) -> CGFloat {
        start + (end - start) * CGFloat(amount)
    }

    private func interpolate(_ start: Double, _ end: Double, _ amount: Double) -> Double {
        start + (end - start) * amount
    }
}

extension ReminderKind {
    var displayName: String {
        switch self {
        case .eye: "护眼"
        case .standing: "站立"
        case .quietPractice: "小动作"
        }
    }

    var symbolName: String {
        switch self {
        case .eye: "eye"
        case .standing: "figure.stand"
        case .quietPractice: "hand.raised"
        }
    }
}
