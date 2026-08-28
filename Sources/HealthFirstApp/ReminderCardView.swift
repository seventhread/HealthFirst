import AppKit
import HealthFirstCore
import SwiftUI

enum CompanionReceiptLayout {
    static let bubbleSize = CGSize(width: 200, height: 70)
    static let bubbleCenterY: CGFloat = 43
    static let genericMascotCenter = CGPoint(x: 112, y: 150)
    static let foldedMascotCenter = CGPoint(x: 112, y: 96)
    static let eyeHeadX: CGFloat = 151
    static let foldedEyeMascotCenter = CGPoint(x: eyeHeadX, y: 96)
    static let standingHeadX: CGFloat = 333

    static func mascotCenter(for receipt: PanelReceipt) -> CGPoint {
        switch receipt {
        case .skipped, .endedEarly:
            foldedMascotCenter
        default:
            genericMascotCenter
        }
    }

    static func bubbleCenterX(forHeadX headX: CGFloat) -> CGFloat {
        min(max(headX, bubbleSize.width / 2 + 12), 420 - bubbleSize.width / 2 - 12)
    }
}

enum QuietCompanionLayout {
    static let initialMascotCenter = CGPoint(x: 87, y: 140)
    static let settledMascotCenter = CGPoint(x: 124, y: 140)
    static let initialDockCenter = CGPoint(x: 263, y: 215)
    static let settledDockCenter = CGPoint(x: 124, y: 43)
    static let dockWidth: CGFloat = 222
    static let dockShadowRadius: CGFloat = 10
}

@MainActor
struct ReminderCardView: View {
    private static let acceptanceDuration: TimeInterval = 1.44
    private enum EyeCompanionLayout {
        static let initialMascotCenter = CGPoint(x: 87, y: 140)
        static let settledMascotCenter = CGPoint(x: 151, y: 140)
        static let initialDockCenter = CGPoint(x: 263, y: 215)
        static let settledDockCenter = CGPoint(x: 145, y: 116)
        static let settledMascotScale = 0.88
    }

    private enum StandingAcceptanceTiming {
        static let reachEnd: TimeInterval = 0.16
        static let pickupEnd: TimeInterval = 0.42
        static let gripEnd: TimeInterval = 0.48
        static let storeEnd: TimeInterval = 0.58
        static let smileStart: TimeInterval = 0.70
        static let smileEnd: TimeInterval = 0.80
        static let fadeEnd: TimeInterval = 0.82
    }

    @ObservedObject var model: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @AccessibilityFocusState private var statusFocused: Bool
    @FocusState private var primaryActionFocused: Bool

    var body: some View {
        ZStack {
            Color.clear
                .frame(width: 420, height: 280)
                .healthFirstCard(chromeOpacity: cardChromeOpacity)
                .allowsHitTesting(false)
                .accessibilityHidden(true)

            guidanceChromeLayer

            cardContentLayer

            acceptanceWorkCardLayer
        }
        .frame(width: 420, height: 280)
        .onHover(perform: model.setPanelHovering)
        .animation(receiptTransitionAnimation, value: model.receipt)
        .animation(
            cardChromeAnimation,
            value: cardChromeOpacity
        )
        .task(id: focusGeneration) {
            // A new hosting view starts with the latest state already set, so
            // relying only on `onChange` can miss its initial focus target.
            await Task.yield()
            statusFocused = true
            primaryActionFocused = shouldFocusPrimaryAction
        }
        .task(id: standingReceiptShouldReveal) {
            guard standingReceiptShouldReveal else { return }
            await Task.yield()
            statusFocused = true
        }
        .accessibilityElement(children: .contain)
    }

    private var contentSpacing: CGFloat {
        model.isGuiding || model.receipt != nil ? 12 : 14
    }

    private var isStandingCompletion: Bool {
        model.receipt == .completed
            && model.activeReminder?.kind == .standing
            && model.exitAnimation == nil
    }

    private var isEyeGuidanceReceipt: Bool {
        guard let reminder = model.activeReminder,
              reminder.kind == .eye,
              reminder.state.isTerminal,
              let receipt = model.receipt,
              model.exitAnimation == nil else {
            return false
        }

        switch receipt {
        case .completed, .endedEarly:
            return true
        case .snoozed, .skipped, .emergencySkipped:
            return false
        }
    }

    private var shouldSimplifyStandingOutro: Bool {
        reduceMotion || NSWorkspace.shared.isVoiceOverEnabled
    }

    private var receiptTransitionAnimation: Animation? {
        guard !reduceMotion, !isStandingCompletion else { return nil }
        return .easeInOut(duration: 0.2)
    }

    private var cardChromeAnimation: Animation? {
        guard !isStandingCompletion else { return nil }
        return reduceMotion
            ? .easeOut(duration: 0.18)
            : .linear(duration: 0.25)
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
        if let receipt = model.receipt,
           isEyeGuidanceReceipt {
            eyeReceiptStage(receipt)
        } else if let reminder = model.activeReminder,
           reminder.kind == .eye,
           case .guided(let startedAt, _) = reminder.state,
           model.exitAnimation == nil,
           model.receipt == nil {
            eyeGuidanceStage(for: reminder, startedAt: startedAt)
        } else if let reminder = model.activeReminder,
           reminder.kind == .quietPractice,
           case .guided = reminder.state,
           model.exitAnimation == nil,
           model.receipt == nil {
            quietGuidanceStage(for: reminder)
        } else if let reminder = model.activeReminder,
           reminder.kind == .standing,
           case .guided = reminder.state,
           model.exitAnimation == nil,
           model.receipt == nil {
            standingGuidanceStage(for: reminder)
        } else if model.receipt == .completed,
                  model.activeReminder?.kind == .standing,
                  model.exitAnimation == nil {
            standingCompletionStage
        } else if let receipt = model.receipt,
                  model.exitAnimation == nil {
            floatingReceiptStage(receipt)
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
        // Completion owns an exact visual clone of the guide's last chrome
        // frame so it can be folded as a prop. Hiding the root immediately
        // avoids both a 0.32 → 1 flash and a doubled material during handoff.
        if model.receipt != nil { return 0 }

        guard let reminder = model.activeReminder,
              case .guided(let startedAt, _) = reminder.state else { return 1 }

        let progress = model.guidanceProgress(for: reminder)
        switch reminder.kind {
        case .eye:
            // The live safety dock owns its own solid surface, so the large
            // 420 x 280 material can clear completely even when Reduce
            // Transparency is enabled.
            return EyeGuideExitTimeline.cardChromeOpacity(
                at: max(0, model.now.timeIntervalSince(startedAt))
            )
        case .standing:
            guard !reduceTransparency else { return 1 }
            let title = motionPhase(
                startSeconds: StandingBeat.title.startSeconds,
                endSeconds: StandingBeat.title.endSeconds,
                totalSeconds: reminder.guideDuration,
                progress: progress
            )
            let backing = motionPhase(
                startSeconds: StandingBeat.backing.startSeconds,
                endSeconds: StandingBeat.backing.endSeconds,
                totalSeconds: reminder.guideDuration,
                progress: progress
            )
            let rails = motionPhase(
                startSeconds: StandingBeat.rails.startSeconds,
                endSeconds: StandingBeat.rails.endSeconds,
                totalSeconds: reminder.guideDuration,
                progress: progress
            )
            let ribbon = motionPhase(
                startSeconds: StandingBeat.ribbon.startSeconds,
                endSeconds: StandingBeat.ribbon.endSeconds,
                totalSeconds: reminder.guideDuration,
                progress: progress
            )
            return 1 - 0.16 * title - 0.16 * backing - 0.16 * rails - 0.20 * ribbon
        case .quietPractice:
            // Quiet guidance deliberately becomes a transparent, minimal
            // floating companion. The solid safety dock remains readable even
            // when Reduce Transparency is enabled, so the large card itself
            // can still disappear without sacrificing control contrast.
            return 1 - motionPhase(
                startSeconds: 0.18,
                endSeconds: 0.78,
                totalSeconds: reminder.guideDuration,
                progress: progress
            )
        }
    }

    @ViewBuilder
    private var guidanceChromeLayer: some View {
        if let reminder = model.activeReminder,
           reminder.kind == .eye,
           case .guided(let startedAt, let endsAt) = reminder.state {
            let timelineIsActive = guidanceChromeTimelineActive(
                kind: reminder.kind,
                startedAt: startedAt
            )
            TimelineView(
                .animation(
                    minimumInterval: reduceMotion ? 0.1 : 1.0 / 30.0,
                    paused: !timelineIsActive
                )
            ) { context in
                let presentationDate = timelineIsActive ? context.date : model.now
                let elapsed = max(
                    0,
                    presentationDate.timeIntervalSince(startedAt)
                )
                GuidanceChromeView(
                    kind: reminder.kind,
                    progress: timelineProgress(
                        startedAt: startedAt,
                        endsAt: endsAt,
                        at: presentationDate
                    ),
                    guideDuration: reminder.guideDuration,
                    reduceMotion: reduceMotion
                )
                .opacity(
                    EyeGuideExitTimeline.decorativeOpacity(at: elapsed)
                )
            }
        }
    }

    /// Eye guidance sheds the reminder card, then keeps one small folded
    /// companion on the desktop. The live safety dock travels above its head
    /// instead of being stranded at the bottom of an otherwise empty panel.
    private func eyeGuidanceStage(
        for reminder: ReminderInstance,
        startedAt: Date
    ) -> some View {
        let elapsed = max(0, model.now.timeIntervalSince(startedAt))
        let settle = EyeGuideExitTimeline.companionProgress(
            at: elapsed,
            reduceMotion: reduceMotion
        )
        let mascotPosition = eyeCompanionPosition(settle: settle)
        let dockPosition = eyeCompanionDockPosition(settle: settle)
        let headerOpacity = guidanceHeaderOpacity(
            for: reminder.kind,
            progress: model.guidanceProgress(for: reminder),
            guideDuration: reminder.guideDuration
        )

        return ZStack(alignment: .topLeading) {
            // Match the prompt's original content-column header so the first
            // second remains continuous while the large material clears.
            reminderHeader(reminder.kind, badge: "陪你一会儿")
                .frame(width: 234, alignment: .leading)
                .position(x: 269, y: 47)
                .opacity(headerOpacity)
                .accessibilityHidden(true)

            mascotLayer
                .scaleEffect(
                    CGFloat(
                        interpolate(
                            from: 1,
                            to: EyeCompanionLayout.settledMascotScale,
                            progress: settle
                        )
                    ),
                    anchor: .center
                )
                .position(x: mascotPosition.x, y: mascotPosition.y)
                .zIndex(4)
                .animation(
                    reduceMotion ? nil : .linear(duration: 0.25),
                    value: settle
                )

            Color.clear
                .frame(width: 1, height: 1)
                .accessibilityElement()
                .accessibilityLabel("护眼提醒，正在看远处")
                .accessibilityFocused($statusFocused)
                .position(x: 145, y: 12)

            guidanceSafetyDock(for: reminder)
                .position(x: dockPosition.x, y: dockPosition.y)
                .zIndex(20)
                .animation(
                    reduceMotion ? nil : .linear(duration: 0.25),
                    value: settle
                )
        }
        .frame(width: 420, height: 280, alignment: .topLeading)
    }

    /// Eye results keep the exact settled companion. Its control dock is
    /// replaced by the same passive speech bubble used by every other result.
    private func eyeReceiptStage(_ receipt: PanelReceipt) -> some View {
        let bubbleCenterX = CompanionReceiptLayout.bubbleCenterX(
            forHeadX: CompanionReceiptLayout.eyeHeadX
        )

        return ZStack(alignment: .topLeading) {
            ProductionMascotView(
                motion: .guidingEye,
                progress: 1,
                actionProgress: 1,
                reduceMotion: reduceMotion
            )
            .frame(width: mascotSize.width, height: mascotSize.height)
            .scaleEffect(
                CGFloat(EyeCompanionLayout.settledMascotScale),
                anchor: .center
            )
            .position(CompanionReceiptLayout.foldedEyeMascotCenter)
            .allowsHitTesting(false)
            .accessibilityHidden(true)

            companionReceiptBubble(
                receipt,
                tailOffset: CompanionReceiptLayout.eyeHeadX - bubbleCenterX
            )
                .position(
                    x: bubbleCenterX,
                    y: CompanionReceiptLayout.bubbleCenterY
                )
                .zIndex(20)
        }
        .frame(width: 420, height: 280, alignment: .topLeading)
    }

    /// Snooze, skip, early-end and quiet-practice results all use the same
    /// compact composition. The panel is transparent; only the companion and
    /// its short-lived message remain on screen.
    private func floatingReceiptStage(_ receipt: PanelReceipt) -> some View {
        let mascotCenter = CompanionReceiptLayout.mascotCenter(for: receipt)
        let headX = mascotCenter.x
        let bubbleCenterX = CompanionReceiptLayout.bubbleCenterX(
            forHeadX: headX
        )

        return ZStack(alignment: .topLeading) {
            mascotLayer
                .position(mascotCenter)
                .zIndex(4)

            companionReceiptBubble(
                receipt,
                tailOffset: headX - bubbleCenterX
            )
                .position(
                    x: bubbleCenterX,
                    y: CompanionReceiptLayout.bubbleCenterY
                )
                .zIndex(20)
        }
        .frame(width: 420, height: 280, alignment: .topLeading)
    }

    /// Quiet practice sheds the full reminder card after acceptance. The
    /// control dock floats above the back-facing mascot, leaving the desktop
    /// visible around both and avoiding any visual hint about the exercise.
    private func quietGuidanceStage(for reminder: ReminderInstance) -> some View {
        let progress = model.guidanceProgress(for: reminder)
        let dockTravel = reduceMotion
            ? 1
            : motionPhase(
                startSeconds: 0.82,
                endSeconds: 1.56,
                totalSeconds: reminder.guideDuration,
                progress: progress
            )
        let dockPosition = quietDockPosition(travel: dockTravel)
        let mascotPosition = quietCompanionPosition(travel: dockTravel)

        return ZStack(alignment: .topLeading) {
            // Begin at the prompt's exact character position, then drift both
            // the companion and its dock onto one shared centre. This keeps
            // the acceptance handoff continuous without leaving the control
            // visibly offset from the character's head.
            mascotLayer
                .position(mascotPosition)
                .zIndex(4)
                .animation(
                    reduceMotion ? nil : .linear(duration: 0.25),
                    value: dockTravel
                )

            Color.clear
                .frame(width: 1, height: 1)
                .accessibilityElement()
                .accessibilityLabel("小动作提醒，陪伴进行中")
                .accessibilityFocused($statusFocused)
                .position(x: mascotPosition.x, y: 12)

            // This is the same live control dock used elsewhere. Once the
            // mascot has turned around, it leaves the old content column on a
            // shallow arc and settles just above the character's head.
            guidanceSafetyDock(for: reminder)
                .position(x: dockPosition.x, y: dockPosition.y)
                .shadow(
                    color: .black.opacity(reduceTransparency ? 0 : 0.10),
                    radius: 10,
                    y: 4
                )
                .zIndex(20)
                .animation(
                    reduceMotion ? nil : .linear(duration: 0.25),
                    value: dockTravel
                )
        }
        .frame(width: 420, height: 280, alignment: .topLeading)
    }

    /// Standing owns the full 420 x 280 presentation stage. The decorative
    /// source fragments and the one shared trolley stay behind both the
    /// character and the real, interactive safety dock.
    @ViewBuilder
    private func standingGuidanceStage(for reminder: ReminderInstance) -> some View {
        if case .guided(let startedAt, _) = reminder.state {
            ZStack(alignment: .topLeading) {
                standingPerformanceLayer(startedAt: startedAt)
                    .zIndex(0)

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
    private func standingPerformanceLayer(startedAt: Date) -> some View {
        if guidanceChromeTimelineActive(kind: .standing, startedAt: startedAt) {
            TimelineView(
                .animation(minimumInterval: reduceMotion ? 0.1 : 1.0 / 30.0)
            ) { context in
                let elapsed = max(0, context.date.timeIntervalSince(startedAt))
                let snapshot = StandingGuideTimeline.snapshot(
                    elapsed: elapsed
                )

                ZStack(alignment: .topLeading) {
                    standingMascotBackLayer(
                        snapshot: snapshot,
                        elapsed: elapsed
                    )
                    StandingAssemblyView(
                        snapshot: snapshot,
                        reduceMotion: reduceMotion
                    )
                    standingMascotFrontLayer(
                        snapshot: snapshot,
                        at: context.date,
                        elapsed: elapsed
                    )
                }
            }
        } else {
            let elapsed = max(0, model.now.timeIntervalSince(startedAt))
            let snapshot = StandingGuideTimeline.snapshot(
                elapsed: elapsed
            )

            ZStack(alignment: .topLeading) {
                standingMascotBackLayer(
                    snapshot: snapshot,
                    elapsed: elapsed
                )
                StandingAssemblyView(
                    snapshot: snapshot,
                    reduceMotion: reduceMotion
                )
                standingMascotFrontLayer(
                    snapshot: snapshot,
                    at: model.now,
                    elapsed: elapsed
                )
            }
        }
    }

    @ViewBuilder
    private func standingMascotBackLayer(
        snapshot: StandingGuideSnapshot,
        elapsed: TimeInterval
    ) -> some View {
        if elapsed >= Self.acceptanceDuration {
            StandingDynamicMascotView(
                snapshot: snapshot,
                reduceMotion: reduceMotion,
                layer: .back
            )
        }
    }

    @ViewBuilder
    private func standingMascotFrontLayer(
        snapshot: StandingGuideSnapshot,
        at date: Date,
        elapsed: TimeInterval
    ) -> some View {
        if elapsed < Self.acceptanceDuration {
            // The existing start-card ritual owns its purpose-built catch and
            // store poses. Once it has settled, the identity-stable articulated
            // arm takes over every long-form trolley collection beat.
            let presentation = mascotPresentation(at: date)
            ProductionMascotView(
                expression: presentation.expression,
                motion: presentation.motion,
                progress: presentation.progress,
                actionProgress: presentation.actionProgress,
                reduceMotion: reduceMotion,
                acceptanceSide: presentation.acceptanceSide,
                standingBeat: presentation.standingBeat
            )
            .frame(
                width: StandingStageGeometry.roleSlot.width,
                height: StandingStageGeometry.roleSlot.height
            )
            .position(
                x: StandingStageGeometry.roleSlot.midX,
                y: StandingStageGeometry.roleSlot.midY
            )
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        } else {
            StandingDynamicMascotView(
                snapshot: snapshot,
                reduceMotion: reduceMotion,
                layer: .front
            )
        }
    }

    /// Completion keeps the exact trolley assembled during guidance. The
    /// rebuilt hosting view deterministically recreates the final countdown
    /// dock and card chrome, then packs them one at a time before revealing a
    /// small, stable receipt outside the display Timeline.
    private var standingCompletionStage: some View {
        let settled = StandingCompletionTimeline.snapshot(
            elapsed: receiptElapsed
        )
        let receiptReveal = shouldSimplifyStandingOutro
            ? 1
            : settled.receiptRevealProgress
        let headX = CompanionReceiptLayout.standingHeadX
        let bubbleCenterX = CompanionReceiptLayout.bubbleCenterX(
            forHeadX: headX
        )

        return ZStack(alignment: .topLeading) {
            TimelineView(
                .animation(
                    minimumInterval: shouldSimplifyStandingOutro ? 0.1 : 1.0 / 30.0,
                    paused: shouldSimplifyStandingOutro
                        || receiptElapsed >= StandingCompletionTimeline.duration
                )
            ) { context in
                let completion = shouldSimplifyStandingOutro
                    ? StandingCompletionSnapshot.completed
                    : StandingCompletionTimeline.snapshot(
                        elapsed: standingCompletionElapsed(at: context.date)
                    )

                ZStack(alignment: .topLeading) {
                    standingCompletionBackdrop(for: completion)

                    StandingDynamicMascotView(
                        snapshot: .completed,
                        reduceMotion: shouldSimplifyStandingOutro,
                        completion: completion,
                        layer: .back
                    )
                    StandingAssemblyView(
                        snapshot: .completed,
                        completion: completion,
                        reduceMotion: shouldSimplifyStandingOutro
                    )
                    StandingDynamicMascotView(
                        snapshot: .completed,
                        reduceMotion: shouldSimplifyStandingOutro,
                        completion: completion,
                        layer: .front
                    )
                }
            }
            .zIndex(0)

            // The passive result bubble remains outside the 30 fps decorative
            // tree and appears only after both props have been stored.
            companionReceiptBubble(
                .completed,
                tailOffset: headX - bubbleCenterX
            )
                .position(
                    x: bubbleCenterX,
                    y: CompanionReceiptLayout.bubbleCenterY
                )
                .offset(
                    y: shouldSimplifyStandingOutro
                        ? 0
                        : CGFloat(7 * (1 - receiptReveal))
                )
                .scaleEffect(CGFloat(0.97 + 0.03 * receiptReveal))
                .opacity(receiptReveal)
                .accessibilityHidden(!standingReceiptShouldReveal)
                .zIndex(20)
                .animation(
                    shouldSimplifyStandingOutro
                        ? nil
                        : .easeOut(duration: 0.22),
                    value: receiptReveal
                )
        }
        .frame(
            width: StandingStageGeometry.size.width,
            height: StandingStageGeometry.size.height,
            alignment: .topLeading
        )
    }

    private func standingCompletionBackdrop(
        for completion: StandingCompletionSnapshot
    ) -> some View {
        StandingCompletionBackdropView(
            completion: completion,
            chromeOpacity: reduceTransparency ? 1 : 0.32,
            reduceMotion: shouldSimplifyStandingOutro
        )
            .allowsHitTesting(false)
            .accessibilityHidden(true)
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
                    paused: model.now.timeIntervalSince(startedAt) >= (
                        reminder.kind == .standing
                            ? StandingAcceptanceTiming.fadeEnd
                            : 0.56
                    )
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
            guideDuration: reminder.guideDuration,
            snoozeDelay: snoozeDelay
        )

        return VStack(alignment: .leading, spacing: 9) {
            reminderHeader(reminder.kind, badge: copy.eyebrow)

            Text(copy.title)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            Text(fromMenuBar ? "我把这张小纸条先夹在菜单栏了。\(copy.message)" : copy.message)
                .font(.system(size: 12.5))
                .foregroundStyle(.secondary)
                .lineSpacing(2)
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
            guideDuration: reminder.guideDuration,
            snoozeDelay: 10 * 60
        )

        return VStack(alignment: .leading, spacing: 10) {
            reminderHeader(reminder.kind, badge: copy.eyebrow)
            Text(copy.title)
                .font(.system(size: 16, weight: .bold, design: .rounded))
            Text(copy.message)
                .font(.system(size: 12.5))
                .foregroundStyle(.secondary)
                .lineSpacing(2)
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
        let progress = model.guidanceProgress(for: reminder)
        let headerOpacity = guidanceHeaderOpacity(
            for: reminder.kind,
            progress: progress,
            guideDuration: reminder.guideDuration
        )

        return VStack(alignment: .leading, spacing: 8) {
            reminderHeader(reminder.kind, badge: "陪你一会儿")
                .opacity(max(0.01, headerOpacity))
                .accessibilityLabel("\(reminder.kind.displayName)提醒，陪伴进行中")
                .accessibilityHidden(false)

            Spacer(minLength: 0)

            guidanceSafetyDock(for: reminder)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .animation(
            reduceMotion ? .easeOut(duration: 0.18) : .linear(duration: 0.25),
            value: headerOpacity
        )
    }

    private func guidanceSafetyDock(for reminder: ReminderInstance) -> some View {
        let remaining = model.remainingSeconds(for: reminder)
        let progress = model.guidanceProgress(for: reminder)
        let actions = ReminderCopy.actionLabels(
            for: reminder.kind,
            tone: model.copyTone,
            guideDuration: reminder.guideDuration
        )

        return VStack(alignment: .leading, spacing: 7) {
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
                return EyeGuideExitTimeline.isMascotTimelineActive(
                    at: elapsed,
                    reduceMotion: reduceMotion
                )
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
            let agreementEnd = reminder.kind == .eye
                ? EyeGuideExitTimeline.agreementEnd
                : 0.56
            if elapsed < agreementEnd {
                let actionProgress = acceptanceActionProgress(
                    for: reminder.kind,
                    elapsed: elapsed
                )
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
                    actionProgress: EyeGuideExitTimeline.handoffProgress(
                        at: elapsed
                    )
                )

            case .standing:
                if elapsed < Self.acceptanceDuration {
                    let actionProgress = acceptanceActionProgress(
                        for: reminder.kind,
                        elapsed: elapsed
                    )
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
                return (.cartHold, 1)
            }
        }

        return elapsed >= StandingBeat.title.endSeconds
            ? (.cartHold, 1)
            : (.inspect, 0.5)
    }

    private func acceptanceActionProgress(
        for kind: ReminderKind,
        elapsed: TimeInterval
    ) -> Double {
        guard kind == .standing else {
            return normalized(elapsed / Self.acceptanceDuration)
        }

        switch elapsed {
        case ..<StandingAcceptanceTiming.reachEnd:
            return interpolate(
                from: 0,
                to: 0.13,
                progress: normalized(
                    elapsed / StandingAcceptanceTiming.reachEnd
                )
            )
        case ..<StandingAcceptanceTiming.pickupEnd:
            return interpolate(
                from: 0.13,
                to: 0.18,
                progress: normalized(
                    (elapsed - StandingAcceptanceTiming.reachEnd)
                        / (StandingAcceptanceTiming.pickupEnd
                            - StandingAcceptanceTiming.reachEnd)
                )
            )
        case ..<StandingAcceptanceTiming.gripEnd:
            return 0.18
        case ..<StandingAcceptanceTiming.storeEnd:
            return interpolate(
                from: 0.18,
                to: 0.24,
                progress: normalized(
                    (elapsed - StandingAcceptanceTiming.gripEnd)
                        / (StandingAcceptanceTiming.storeEnd
                            - StandingAcceptanceTiming.gripEnd)
                )
            )
        case ..<StandingAcceptanceTiming.smileStart:
            return 0.24
        case ..<StandingAcceptanceTiming.smileEnd:
            return interpolate(
                from: 0.24,
                to: 0.36,
                progress: normalized(
                    (elapsed - StandingAcceptanceTiming.smileStart)
                        / (StandingAcceptanceTiming.smileEnd
                            - StandingAcceptanceTiming.smileStart)
                )
            )
        default:
            return interpolate(
                from: 0.36,
                to: 1,
                progress: normalized(
                    (elapsed - StandingAcceptanceTiming.smileEnd)
                        / (Self.acceptanceDuration
                            - StandingAcceptanceTiming.smileEnd)
                )
            )
        }
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
        let elapsed = date.timeIntervalSince(startedAt)
        return EyeGuideExitTimeline.mascotOpacity(
            at: elapsed,
            reduceMotion: reduceMotion
        )
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

    private func interpolate(
        from start: Double,
        to end: Double,
        progress: Double
    ) -> Double {
        start + (end - start) * normalized(progress)
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

    private func quietDockPosition(travel: Double) -> CGPoint {
        let clamped = normalized(travel)
        let eased = clamped * clamped * (3 - 2 * clamped)
        let arc = sin(clamped * .pi) * 12

        return CGPoint(
            x: CGFloat(
                interpolate(
                    from: Double(QuietCompanionLayout.initialDockCenter.x),
                    to: Double(QuietCompanionLayout.settledDockCenter.x),
                    progress: eased
                )
            ),
            y: CGFloat(
                interpolate(
                    from: Double(QuietCompanionLayout.initialDockCenter.y),
                    to: Double(QuietCompanionLayout.settledDockCenter.y),
                    progress: eased
                ) - arc
            )
        )
    }

    private func quietCompanionPosition(travel: Double) -> CGPoint {
        let clamped = normalized(travel)
        let eased = clamped * clamped * (3 - 2 * clamped)

        return CGPoint(
            x: CGFloat(
                interpolate(
                    from: Double(QuietCompanionLayout.initialMascotCenter.x),
                    to: Double(QuietCompanionLayout.settledMascotCenter.x),
                    progress: eased
                )
            ),
            y: QuietCompanionLayout.settledMascotCenter.y
        )
    }

    private func eyeCompanionPosition(settle: Double) -> CGPoint {
        let clamped = normalized(settle)
        let arc = sin(clamped * .pi) * 5

        return CGPoint(
            x: CGFloat(
                interpolate(
                    from: Double(EyeCompanionLayout.initialMascotCenter.x),
                    to: Double(EyeCompanionLayout.settledMascotCenter.x),
                    progress: clamped
                )
            ),
            y: CGFloat(
                interpolate(
                    from: Double(EyeCompanionLayout.initialMascotCenter.y),
                    to: Double(EyeCompanionLayout.settledMascotCenter.y),
                    progress: clamped
                ) - arc
            )
        )
    }

    private func eyeCompanionDockPosition(settle: Double) -> CGPoint {
        let clamped = normalized(settle)
        let arc = sin(clamped * .pi) * 10

        return CGPoint(
            x: CGFloat(
                interpolate(
                    from: Double(EyeCompanionLayout.initialDockCenter.x),
                    to: Double(EyeCompanionLayout.settledDockCenter.x),
                    progress: clamped
                )
            ),
            y: CGFloat(
                interpolate(
                    from: Double(EyeCompanionLayout.initialDockCenter.y),
                    to: Double(EyeCompanionLayout.settledDockCenter.y),
                    progress: clamped
                ) - arc
            )
        )
    }

    private func guidanceHeaderOpacity(
        for kind: ReminderKind,
        progress: Double,
        guideDuration: TimeInterval
    ) -> Double {
        switch kind {
        case .eye:
            return 1 - motionPhase(
                startSeconds: 0.56,
                endSeconds: 1.10,
                totalSeconds: guideDuration,
                progress: progress
            )
        case .standing:
            return 1 - motionPhase(
                startSeconds: StandingBeat.title.startSeconds,
                endSeconds: StandingBeat.title.endSeconds,
                totalSeconds: guideDuration,
                progress: progress
            )
        case .quietPractice:
            return 1 - motionPhase(
                startSeconds: 0.56,
                endSeconds: 0.81,
                totalSeconds: guideDuration,
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
            return elapsed < EyeGuideExitTimeline.decorativeFadeEnd
        case .quietPractice:
            return elapsed < 1.46
        case .standing:
            return elapsed < Self.acceptanceDuration
                || standingVisualTimelineActive(elapsed: elapsed)
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

    private var standingReceiptShouldReveal: Bool {
        guard isStandingCompletion else { return false }
        if shouldSimplifyStandingOutro { return true }
        return StandingCompletionTimeline.snapshot(
            elapsed: receiptElapsed
        ).isReadyForReceipt
    }

    private var shouldFocusPrimaryAction: Bool {
        if model.receipt != nil { return false }
        guard let reminder = model.activeReminder else { return false }
        switch reminder.state {
        case .firstPresented, .followUpPresented, .pendingInMenuBar, .seriousPresented:
            return true
        default:
            return false
        }
    }

    private func companionReceiptBubble(
        _ receipt: PanelReceipt,
        tailOffset: CGFloat
    ) -> some View {
        let copy = receiptCopy(for: receipt)

        return CompanionReceiptBubble(
            copy: copy,
            isPositive: receipt.isPositive,
            tailOffset: tailOffset,
            usesOpaqueSurface: reduceTransparency
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(copy.title)，\(copy.message)")
        .accessibilityHint(
            NSWorkspace.shared.isVoiceOverEnabled
                ? "使用关闭操作收起"
                : "几秒后自动收起"
        )
        .accessibilityFocused($statusFocused)
        .accessibilityAction(named: Text("关闭")) {
            model.dismissReceipt()
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
        case .standing: StandingCompletionTimeline.duration
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
        let guideDuration = model.activeReminder?.guideDuration
        return switch receipt {
        case .completed:
            ReminderCopy.receipt(
                for: kind,
                outcome: .completed,
                tone: model.copyTone,
                guideDuration: guideDuration
            )
        case .snoozed(let minutes):
            ReminderCopy.receipt(
                for: kind,
                outcome: .snoozed(delay: TimeInterval(minutes * 60)),
                tone: model.copyTone,
                guideDuration: guideDuration
            )
        case .skipped:
            ReminderCopy.receipt(
                for: kind,
                outcome: .skipped,
                tone: model.copyTone,
                guideDuration: guideDuration
            )
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

struct CompanionReceiptBubble: View {
    let copy: ReminderReceiptCopy
    let isPositive: Bool
    let tailOffset: CGFloat
    let usesOpaqueSurface: Bool

    private var surface: Color {
        usesOpaqueSurface
            ? HealthFirstStyle.surface
            : HealthFirstStyle.secondarySurface.opacity(0.97)
    }

    private var clampedTailOffset: CGFloat {
        min(max(tailOffset, -72), 72)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            CompanionReceiptTail()
                .fill(surface)
                .overlay {
                    CompanionReceiptTail()
                        .stroke(Color.primary.opacity(0.09), lineWidth: 0.8)
                }
                .frame(width: 18, height: 10)
                .position(
                    x: 100 + clampedTailOffset,
                    y: 63
                )

            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(surface)
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.09), lineWidth: 0.8)
                }
                .frame(width: 200, height: 60)

            VStack(alignment: .leading, spacing: 3) {
                Text(copy.title)
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(
                        isPositive ? HealthFirstStyle.orange : .secondary
                    )

                Text(copy.message)
                    .font(.system(size: 13.5, weight: .semibold, design: .rounded))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .frame(width: 200, height: 60, alignment: .topLeading)
        }
        .frame(width: 200, height: 70, alignment: .topLeading)
        .shadow(
            color: .black.opacity(usesOpaqueSurface ? 0 : 0.05),
            radius: 6,
            y: 2
        )
    }
}

private struct CompanionReceiptTail: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.closeSubpath()
        return path
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

    private var usesStandingTiming: Bool {
        direction == .viewerLeft
    }

    private var collectionStart: TimeInterval {
        usesStandingTiming ? 0.16 : 0.04
    }

    private var pickupEnd: TimeInterval {
        usesStandingTiming ? 0.42 : 0.26
    }

    private var gripEnd: TimeInterval {
        usesStandingTiming ? 0.48 : 0.26
    }

    private var storeEnd: TimeInterval {
        usesStandingTiming ? 0.58 : 0.46
    }

    private var shrinkEnd: TimeInterval {
        usesStandingTiming ? 0.58 : 0.50
    }

    private var fadeStart: TimeInterval {
        usesStandingTiming ? 0.72 : 0.44
    }

    private var fadeEnd: TimeInterval {
        usesStandingTiming ? 0.82 : 0.56
    }

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

        if elapsed < collectionStart {
            return buttonPoint
        }

        if elapsed < pickupEnd {
            let amount = eased(phase(from: collectionStart, to: pickupEnd))
            return CGPoint(
                x: interpolateCGFloat(buttonPoint.x, catchPoint.x, amount),
                y: interpolateCGFloat(buttonPoint.y, catchPoint.y, amount)
                    - CGFloat(15 * sin(amount * .pi))
            )
        }

        if elapsed < gripEnd {
            return catchPoint
        }

        let amount = eased(phase(from: gripEnd, to: storeEnd))
        return CGPoint(
            x: interpolateCGFloat(catchPoint.x, reelPoint.x, amount),
            y: interpolateCGFloat(catchPoint.y, reelPoint.y, amount)
                - CGFloat(4 * sin(amount * .pi))
        )
    }

    private var cardSize: CGSize {
        guard !reduceMotion else { return CGSize(width: 38, height: 22) }

        if elapsed < collectionStart {
            return CGSize(width: 72, height: 30)
        }

        if elapsed < pickupEnd {
            let amount = eased(phase(from: collectionStart, to: pickupEnd))
            return CGSize(
                width: interpolateCGFloat(72, 42, amount),
                height: interpolateCGFloat(30, 24, amount)
            )
        }

        if elapsed < gripEnd {
            return CGSize(width: 42, height: 24)
        }

        let amount = eased(phase(from: gripEnd, to: shrinkEnd))
        return CGSize(
            width: interpolateCGFloat(42, 18, amount),
            height: interpolateCGFloat(24, 10, amount)
        )
    }

    private var rotation: Double {
        guard !reduceMotion else { return 0 }
        if elapsed < collectionStart {
            return 0
        }
        if elapsed < pickupEnd {
            return interpolate(
                0,
                -8,
                eased(phase(from: collectionStart, to: pickupEnd))
            )
        }
        if elapsed < gripEnd {
            return -8
        }
        return interpolate(-8, 12, eased(phase(from: gripEnd, to: shrinkEnd)))
    }

    private var opacity: Double {
        if reduceMotion {
            let fadeIn = phase(from: 0.08, to: 0.16)
            let fadeOut = phase(from: 0.34, to: 0.50)
            return fadeIn * (1 - fadeOut)
        }
        return 1 - phase(from: fadeStart, to: fadeEnd)
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
