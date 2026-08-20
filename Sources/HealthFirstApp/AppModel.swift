import AppKit
import Foundation
import HealthFirstCore
import SwiftUI

enum PanelReceipt: Equatable {
    case completed
    case snoozed(minutes: Int)
    case skipped
    case endedEarly
    case emergencySkipped

    var isPositive: Bool {
        if case .completed = self { return true }
        return false
    }
}

enum PanelExitAnimation: Equatable {
    case retry(ReminderKind)
    case queued(ReminderKind)

    var kind: ReminderKind {
        switch self {
        case .retry(let kind), .queued(let kind):
            kind
        }
    }

    var isRetry: Bool {
        if case .retry = self { return true }
        return false
    }
}

private struct RuntimeSettings: Equatable {
    var eyeEnabled: Bool
    var eyeIntervalMinutes: Int
    var standingEnabled: Bool
    var standingIntervalMinutes: Int
    var quietEnabled: Bool
    var quietDailyCount: Int
    var seriousMode: Bool
    var workdayStartHour: Int
    var workdayEndHour: Int
}

/// System notifications overlap in normal use: locking can put the displays
/// to sleep, and a full machine sleep can happen while the session is already
/// inactive. Keeping the reasons separate lets AppModel freeze one union of
/// those intervals instead of applying the same elapsed time more than once.
private enum ClockSuspensionReason: Hashable {
    case systemSleep
    case screenSleep
    case sessionInactive
}

/// NotificationCenter tokens are Objective-C objects and therefore are not
/// Sendable. Keeping them in a lifetime-isolated bag avoids
/// reaching across AppModel's nonisolated deinit while still guaranteeing that
/// every observer is removed.
private final class NotificationObserverBag: @unchecked Sendable {
    private let notificationCenter: NotificationCenter
    private var observers: [NSObjectProtocol] = []

    init(notificationCenter: NotificationCenter) {
        self.notificationCenter = notificationCenter
    }

    func store(_ observers: [NSObjectProtocol]) {
        self.observers = observers
    }

    deinit {
        for observer in observers {
            notificationCenter.removeObserver(observer)
        }
    }
}

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var now = Date()
    @Published private(set) var nextDue: [ReminderKind: Date] = [:]
    @Published private(set) var activeReminder: ReminderInstance?
    @Published private(set) var pendingReminders: [ReminderInstance] = []
    @Published private(set) var receipt: PanelReceipt?
    @Published private(set) var receiptStartedAt: Date?
    @Published private(set) var exitAnimation: PanelExitAnimation?
    @Published private(set) var exitAnimationStartedAt: Date?
    @Published private(set) var panelPresentationStartedAt: Date?
    @Published private(set) var pausedUntil: Date?
    @Published private(set) var lastError: String?

    private let panelController = ReminderPanelController()
    private var tickTask: Task<Void, Never>?
    private var autoDismissAt: Date?
    private var remainingAutoDismiss: TimeInterval?
    private var receiptDismissAt: Date?
    private var exitAnimationDismissAt: Date?
    private var remainingReceiptDismiss: TimeInterval?
    private var remainingExitAnimationDismiss: TimeInterval?
    private var clockSuspensionStartedAt: Date?
    private var manualPauseIntent: ManualPauseIntent?
    private var wallClockJumpDetector = WallClockJumpDetector()
    private var systemInactivity = SystemInactivityTracker<ClockSuspensionReason>()
    // Dates placed on a later workday cannot reveal whether they represent a
    // full interval or a partial remainder (for example, 09:05). Keep that
    // semantic amount alongside nextDue so repeated rebases remain lossless.
    private var deferredIntervalRemaining: [ReminderKind: TimeInterval] = [:]
    private var suspendedSchedule: ReminderSchedulePolicy.ScheduleSnapshot?
    private var guidanceSchedule: ReminderSchedulePolicy.ScheduleSnapshot?
    private let workspaceObservers = NotificationObserverBag(
        notificationCenter: NSWorkspace.shared.notificationCenter
    )
    private let systemTimeObservers = NotificationObserverBag(
        notificationCenter: .default
    )
    private var panelWasVisibleBeforePause = false
    private var panelIsHovered = false
    private var panelHasKeyboardFocus = false
    private var schedulingCalendar: Calendar
    private var lastSettings: RuntimeSettings
    private var activeIsManual = false

    init() {
        Self.registerDefaults()
        schedulingCalendar = Calendar.current
        lastSettings = Self.readSettings()
        let launchContinuousInstant = ContinuousClock.now
        let launchDate = Date()
        now = launchDate
        _ = wallClockJumpDetector.observe(
            wallDate: launchDate,
            continuousInstant: launchContinuousInstant
        )
        rebuildSchedule(from: launchDate)
        panelController.setKeyStateHandler { [weak self] hasFocus in
            self?.setPanelKeyboardFocus(hasFocus)
        }
        installWorkspaceSuspensionObservers()
        installSystemTimeObservers()

        tickTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(250))
                guard let self else { return }
                let continuousInstant = ContinuousClock.now
                let wallDate = Date()
                self.tick(
                    at: wallDate,
                    continuousInstant: continuousInstant
                )
            }
        }
    }

    deinit {
        tickTask?.cancel()
    }

    var hasPendingReminder: Bool {
        !pendingReminders.isEmpty
    }

    var isGuiding: Bool {
        guard let reminder = activeReminder else { return false }
        if case .guided = reminder.state { return true }
        return false
    }

    var canTriggerPreview: Bool {
        activeReminder == nil
            && receipt == nil
            && exitAnimation == nil
            && !isPaused
    }

    var menuBarSymbol: String {
        if hasPendingReminder { return "bookmark.fill" }
        if isPaused { return "pause.circle.fill" }
        if isGuiding { return "hourglass" }
        return "sparkles"
    }

    var menuBarAccessibilityLabel: String {
        if hasPendingReminder { return "HealthFirst，有一个待处理提醒" }
        if isPaused { return "HealthFirst，提醒已暂停" }
        if isGuiding { return "HealthFirst，正在陪伴练习" }
        return "HealthFirst，健康提醒运行中"
    }

    var isPaused: Bool {
        guard let pausedUntil else { return false }
        return pausedUntil > now
    }

    var copyTone: ReminderCopyTone {
        let rawValue = UserDefaults.standard.string(forKey: SettingsKey.copyTone)
        return ReminderCopyTone(rawValue: rawValue ?? "") ?? .gentle
    }

    func triggerPreview(_ kind: ReminderKind) {
        let eventDate = observeCurrentWallClock()
        guard canTriggerPreview else { return }

        receipt = nil
        receiptStartedAt = nil
        receiptDismissAt = nil
        lastError = nil
        var reminder = ReminderInstance(
            kind: kind,
            dueAt: eventDate,
            mode: lastSettings.seriousMode ? .serious : .standard
        )
        do {
            try reminder.send(.deadlineReached, at: eventDate)
            activeReminder = reminder
            activeIsManual = true
            presentPanel(autoDismissAfter: 8, userInitiated: true)
        } catch {
            record(error)
        }
    }

#if DEBUG
    func triggerSeriousPreview(_ kind: ReminderKind = .standing) {
        let eventDate = observeCurrentWallClock()
        guard canTriggerPreview else { return }

        var reminder = ReminderInstance(
            kind: kind,
            dueAt: eventDate,
            mode: .serious,
            retryDelay: 0
        )
        do {
            try reminder.send(.deadlineReached, at: eventDate)
            try reminder.send(.noResponse, at: eventDate)
            try reminder.send(.deadlineReached, at: eventDate)
            try reminder.send(.noResponse, at: eventDate)
            activeReminder = reminder
            activeIsManual = true
            presentPanel(autoDismissAfter: nil, userInitiated: true)
        } catch {
            record(error)
        }
    }
#endif

    func openPendingReminder() {
        _ = observeCurrentWallClock()
        guard activeReminder == nil,
              receipt == nil,
              exitAnimation == nil,
              !isPaused else { return }
        guard !pendingReminders.isEmpty else { return }
        receipt = nil
        activeReminder = pendingReminders.removeFirst()
        // A queued scheduled reminder already caused its next occurrence to be
        // scheduled when it entered the queue.
        activeIsManual = true
        presentPanel(autoDismissAfter: nil, userInitiated: true)
    }

    func startActiveReminder() {
        guard let state = activeReminder?.state else { return }
        switch state {
        case .firstPresented, .followUpPresented, .pendingInMenuBar, .seriousPresented:
            break
        default:
            return
        }

        apply(.start) { [weak self] state in
            guard let self else { return }
            if case .guided(let startedAt, _) = state {
                self.guidanceSchedule = self.reminderSchedulePolicy
                    .captureForGuidance(
                        nextDue: self.nextDue,
                        deferredIntervalRemaining:
                            self.deferredIntervalRemaining,
                        at: startedAt
                    )
                if let guidanceSchedule = self.guidanceSchedule {
                    self.updateDeferredIntervalRemaining(
                        self.reminderSchedulePolicy.intervalRemaining(
                            in: guidanceSchedule,
                            systemInactivity: 0
                        )
                    )
                }
                self.autoDismissAt = nil
                self.remainingAutoDismiss = nil
                self.presentPanel(autoDismissAfter: nil, userInitiated: true)
            }
        }
    }

    func snoozeActiveReminder() {
        guard let state = activeReminder?.state else { return }
        let minutes: Int
        switch state {
        case .firstPresented:
            minutes = 3
        case .followUpPresented:
            minutes = 10
        default:
            return
        }

        apply(.snooze(for: TimeInterval(minutes * 60))) { [weak self] _ in
            self?.showReceipt(.snoozed(minutes: minutes), keepReminder: true)
        }
    }

    func skipActiveReminder() {
        apply(.skip) { [weak self] _ in
            self?.showReceipt(.skipped, keepReminder: false)
        }
    }

    func endGuidanceEarly() {
        apply(.earlyEnd) { [weak self] _ in
            guard let self else { return }
            self.restoreGuidanceSchedule(at: self.now)
            self.showReceipt(.endedEarly, keepReminder: false)
        }
    }

    func emergencySkip() {
        apply(.emergencySkip) { [weak self] _ in
            guard let self else { return }
            self.restoreGuidanceSchedule(at: self.now)
            self.showReceipt(.emergencySkipped, keepReminder: false)
        }
    }

    func setPanelHovering(_ hovering: Bool) {
        panelIsHovered = hovering
        updatePanelInteractionPause()
    }

    private func setPanelKeyboardFocus(_ hasFocus: Bool) {
        panelHasKeyboardFocus = hasFocus
        updatePanelInteractionPause()
    }

    private func updatePanelInteractionPause() {
        if panelIsHovered || panelHasKeyboardFocus {
            if let autoDismissAt {
                remainingAutoDismiss = max(0, autoDismissAt.timeIntervalSince(now))
                self.autoDismissAt = nil
            }
            if let receiptDismissAt {
                remainingReceiptDismiss = max(0, receiptDismissAt.timeIntervalSince(now))
                self.receiptDismissAt = nil
            }
        } else if clockSuspensionStartedAt == nil {
            if let remainingAutoDismiss {
                autoDismissAt = now.addingTimeInterval(remainingAutoDismiss)
                self.remainingAutoDismiss = nil
            }
            if let remainingReceiptDismiss {
                receiptDismissAt = now.addingTimeInterval(remainingReceiptDismiss)
                self.remainingReceiptDismiss = nil
            }
        }
    }

    func pause(for duration: TimeInterval) {
        _ = observeCurrentWallClock()
        beginPause(
            until: now.addingTimeInterval(duration),
            intent: .duration
        )
    }

    func pauseUntilTomorrow() {
        _ = observeCurrentWallClock()
        let calendar = schedulingCalendar
        let tomorrow = calendar.date(
            byAdding: .day,
            value: 1,
            to: now
        ) ?? now.addingTimeInterval(86_400)
        let hour = UserDefaults.standard.integer(
            forKey: SettingsKey.workdayStartHour
        )
        let until = calendar.date(
            bySettingHour: hour,
            minute: 0,
            second: 0,
            of: tomorrow
        ) ?? tomorrow
        beginPause(
            until: until,
            intent: .calendar(
                CalendarPauseAnchor(target: until, calendar: calendar)
            )
        )
    }

    func resume() {
        let eventDate = observeCurrentWallClock()
        endPause(at: eventDate, userInitiated: true)
    }

    func dismissReceipt() {
        _ = observeCurrentWallClock()
        finishReceipt()
    }

    func nextDueDate(for kind: ReminderKind) -> Date? {
        nextDue[kind]
    }

    func remainingSeconds(for reminder: ReminderInstance) -> Int {
        guard case .guided(_, let endsAt) = reminder.state else { return 0 }
        return max(0, Int(ceil(endsAt.timeIntervalSince(now))))
    }

    func guidanceProgress(for reminder: ReminderInstance) -> Double {
        guard case .guided(let startedAt, let endsAt) = reminder.state else { return 0 }
        let duration = endsAt.timeIntervalSince(startedAt)
        guard duration > 0 else { return 1 }
        return min(1, max(0, now.timeIntervalSince(startedAt) / duration))
    }

    @discardableResult
    private func observeCurrentWallClock(
        forceCalendarRebase: Bool = false
    ) -> Date {
        let continuousInstant = ContinuousClock.now
        let wallDate = Date()
        observeWallClock(
            at: wallDate,
            continuousInstant: continuousInstant,
            forceCalendarRebase: forceCalendarRebase
        )
        return wallDate
    }

    private func observeWallClock(
        at wallDate: Date,
        continuousInstant: ContinuousClock.Instant,
        forceCalendarRebase: Bool = false
    ) {
        let updatedCalendar = Calendar.current
        let offset = wallClockJumpDetector.observe(
            wallDate: wallDate,
            continuousInstant: continuousInstant
        ) ?? 0
        let calendarChanged = Self.calendarEnvironmentDiffers(
            schedulingCalendar,
            updatedCalendar
        )

        if offset != 0 || calendarChanged || forceCalendarRebase {
            rebaseTimeEnvironment(
                by: offset,
                from: wallDate.addingTimeInterval(-offset),
                to: wallDate,
                updatedCalendar: updatedCalendar
            )
            schedulingCalendar = updatedCalendar
        }
        now = wallDate
    }

    private func rebaseTimeEnvironment(
        by offset: TimeInterval,
        from dateBeforeChange: Date,
        to wallDate: Date,
        updatedCalendar: Calendar
    ) {
        guard offset.isFinite else { return }

        let previousPolicy = makeReminderSchedulePolicy(
            calendar: schedulingCalendar
        )
        let updatedPolicy = makeReminderSchedulePolicy(
            calendar: updatedCalendar
        )
        let liveSchedule = previousPolicy.captureForClockRebase(
            nextDue: nextDue,
            deferredIntervalRemaining: deferredIntervalRemaining,
            at: dateBeforeChange
        )

        if offset != 0 {
            do {
                var rebasedActive = activeReminder
                if var reminder = rebasedActive {
                    try reminder.send(
                        .wallClockAdjusted(by: offset),
                        at: wallDate
                    )
                    rebasedActive = reminder
                }

                var rebasedPending: [ReminderInstance] = []
                rebasedPending.reserveCapacity(pendingReminders.count)
                for var reminder in pendingReminders {
                    try reminder.send(
                        .wallClockAdjusted(by: offset),
                        at: wallDate
                    )
                    rebasedPending.append(reminder)
                }

                activeReminder = rebasedActive
                pendingReminders = rebasedPending
            } catch {
                // The detector only produces finite offsets and the rebase event
                // is valid in every state. Keep the remaining clock graph
                // untouched if that invariant is ever broken rather than
                // applying half a shift.
                lastError = String(describing: error)
                return
            }
        }

        // Live deadlines have different identities. Interval reminders retain
        // active-work remaining and are laid back into the updated workday;
        // future quiet reminders realign to cadence, while already-overdue quiet
        // occurrences stay overdue so a blocked occurrence is not swallowed.
        nextDue = updatedPolicy.restoreAfterClockRebase(
            liveSchedule,
            at: wallDate
        )
        updateDeferredIntervalRemaining(
            updatedPolicy.intervalRemaining(in: liveSchedule)
        )

        autoDismissAt = autoDismissAt?.addingTimeInterval(offset)
        receiptDismissAt = receiptDismissAt?.addingTimeInterval(offset)
        exitAnimationDismissAt = exitAnimationDismissAt?.addingTimeInterval(
            offset
        )
        receiptStartedAt = receiptStartedAt?.addingTimeInterval(offset)
        exitAnimationStartedAt = exitAnimationStartedAt?.addingTimeInterval(
            offset
        )
        panelPresentationStartedAt = panelPresentationStartedAt?.addingTimeInterval(
            offset
        )

        if let manualPauseIntent {
            pausedUntil = manualPauseIntent.rebasedDeadline(
                pausedUntil,
                from: dateBeforeChange,
                to: wallDate,
                calendar: updatedCalendar
            )
        } else {
            // Defensive fallback for state restored by an older build.
            pausedUntil = pausedUntil?.addingTimeInterval(offset)
        }

        clockSuspensionStartedAt = clockSuspensionStartedAt?.addingTimeInterval(
            offset
        )
        systemInactivity.rebaseWallClock(by: offset)

        if let suspendedSchedule {
            self.suspendedSchedule = updatedPolicy.rebasing(
                suspendedSchedule,
                by: offset
            )
        }
        if let guidanceSchedule {
            self.guidanceSchedule = updatedPolicy.rebasing(
                guidanceSchedule,
                by: offset
            )
        }
    }

    private static func calendarEnvironmentDiffers(
        _ previous: Calendar,
        _ current: Calendar
    ) -> Bool {
        previous.identifier != current.identifier
            || previous.timeZone != current.timeZone
            || previous.locale?.identifier != current.locale?.identifier
            || previous.firstWeekday != current.firstWeekday
            || previous.minimumDaysInFirstWeek != current.minimumDaysInFirstWeek
    }

    private func tick(
        at date: Date,
        continuousInstant: ContinuousClock.Instant
    ) {
        observeWallClock(
            at: date,
            continuousInstant: continuousInstant
        )

        if let pausedUntil, pausedUntil <= date {
            endPause(at: date, userInitiated: false)
        }

        // Manual pause, sleep, display sleep, and lock-screen intervals all
        // share one clock freeze. `isPaused` intentionally remains the public
        // manual-pause state used by the menu bar.
        guard clockSuspensionStartedAt == nil else { return }

        // Defer settings reconciliation while the clock or reminder schedule
        // is frozen. Otherwise changing an interval mid-pause/mid-guidance
        // would create a new wall-clock due and then overwrite it with the
        // captured remaining time. The first tick after either flow finishes
        // reconciles once from its real resume date.
        let settings = Self.readSettings()
        if settings != lastSettings, guidanceSchedule == nil {
            let previousSettings = lastSettings
            lastSettings = settings
            reconcileSchedule(
                previous: previousSettings,
                current: settings,
                from: date
            )
        }

        expireStaleQuietReminders(at: date)

        if let exitAnimationDismissAt, exitAnimationDismissAt <= date {
            finishExitAnimation()
            return
        }

        if let receiptDismissAt, receiptDismissAt <= date {
            finishReceipt()
            return
        }

        // A visible receipt is modal presentation state. In particular,
        // VoiceOver receipts have no automatic timeout; do not advance a
        // snoozed reminder invisibly behind one while it is being read.
        guard receipt == nil else { return }

        if let autoDismissAt, autoDismissAt <= date {
            handleNoResponse(at: date)
            return
        }

        if var reminder = activeReminder,
           let deadline = reminder.state.nextDeadline,
           deadline <= date {
            do {
                switch reminder.state {
                case .guided:
                    try reminder.send(.countdownCompleted, at: date)
                    activeReminder = reminder
                    restoreGuidanceSchedule(at: date)
                    showReceipt(.completed, keepReminder: false)
                default:
                    try reminder.send(.deadlineReached, at: date)
                    activeReminder = reminder
                    presentPanel(
                        autoDismissAfter: presentationTimeout(for: reminder.state),
                        userInitiated: false
                    )
                }
            } catch {
                record(error)
            }
            return
        }

        guard activeReminder == nil,
              exitAnimation == nil,
              isWithinWorkday(date) else { return }
        guard let due = nextDue
            .filter({ $0.value <= date })
            .min(by: { $0.value < $1.value }) else { return }

        var reminder = ReminderInstance(
            kind: due.key,
            dueAt: due.value,
            mode: lastSettings.seriousMode ? .serious : .standard
        )
        do {
            try reminder.send(.deadlineReached, at: date)
            setNextDue(nil, for: due.key)
            activeReminder = reminder
            activeIsManual = false
            presentPanel(autoDismissAfter: 8, userInitiated: false)
        } catch {
            record(error)
        }
    }

    private func apply(
        _ event: ReminderEvent,
        completion: (ReminderState) -> Void
    ) {
        let eventDate = observeCurrentWallClock()
        guard var reminder = activeReminder else { return }
        guard receipt == nil else { return }

        do {
            let state = try reminder.send(event, at: eventDate)
            activeReminder = reminder
            autoDismissAt = nil
            remainingAutoDismiss = nil
            completion(state)
        } catch {
            record(error)
        }
    }

    private func handleNoResponse(at date: Date) {
        guard var reminder = activeReminder else { return }
        do {
            let state = try reminder.send(.noResponse, at: date)
            activeReminder = reminder
            autoDismissAt = nil
            remainingAutoDismiss = nil

            switch state {
            case .seriousPresented:
                presentPanel(autoDismissAfter: 15, userInitiated: false)
            case .pendingInMenuBar:
                if let index = pendingReminders.firstIndex(
                    where: { $0.kind == reminder.kind }
                ) {
                    pendingReminders[index] = reminder
                } else {
                    pendingReminders.append(reminder)
                }
                if !activeIsManual {
                    setNextDue(
                        nextScheduledDate(
                            for: reminder.kind,
                            after: date
                        ),
                        for: reminder.kind
                    )
                }
                activeReminder = nil
                activeIsManual = false
                beginExitAnimation(.queued(reminder.kind), forceCompact: true)
            case .retryPending:
                beginExitAnimation(.retry(reminder.kind), forceCompact: false)
            default:
                panelController.dismiss()
            }
        } catch {
            record(error)
        }
    }

    private func beginPause(
        until: Date,
        intent: ManualPauseIntent
    ) {
        guard until > now else { return }

        pausedUntil = until
        manualPauseIntent = intent
        beginClockSuspensionIfNeeded(at: now)
    }

    private func endPause(at date: Date, userInitiated: Bool) {
        pausedUntil = nil
        manualPauseIntent = nil
        finishClockSuspensionIfPossible(at: date, userInitiated: userInitiated)
    }

    private func beginClockSuspensionIfNeeded(at date: Date) {
        guard clockSuspensionStartedAt == nil else { return }

        clockSuspensionStartedAt = date
        systemInactivity.reset()
        suspendedSchedule = reminderSchedulePolicy.captureForSuspension(
            nextDue: nextDue,
            deferredIntervalRemaining: deferredIntervalRemaining,
            at: date
        )
        if let suspendedSchedule {
            updateDeferredIntervalRemaining(
                reminderSchedulePolicy.intervalRemaining(
                    in: suspendedSchedule,
                    systemInactivity: 0
                )
            )
        }
        panelWasVisibleBeforePause = panelController.isVisible

        if let autoDismissAt {
            remainingAutoDismiss = max(0, autoDismissAt.timeIntervalSince(date))
            self.autoDismissAt = nil
        }
        if let receiptDismissAt {
            remainingReceiptDismiss = max(0, receiptDismissAt.timeIntervalSince(date))
            self.receiptDismissAt = nil
        }
        if let exitAnimationDismissAt {
            remainingExitAnimationDismiss = max(
                0,
                exitAnimationDismissAt.timeIntervalSince(date)
            )
            self.exitAnimationDismissAt = nil
        }

        panelController.dismiss()
        panelIsHovered = false
        panelHasKeyboardFocus = false
    }

    private func finishClockSuspensionIfPossible(
        at date: Date,
        userInitiated: Bool
    ) {
        guard pausedUntil == nil,
              !systemInactivity.isInactive,
              let clockSuspensionStartedAt else { return }

        let suspendedDuration = max(
            0,
            date.timeIntervalSince(clockSuspensionStartedAt)
        )
        let schedulePolicy = reminderSchedulePolicy
        let naturalEyeRest = schedulePolicy.isNaturalEyeRest(
            systemInactivity.accumulatedDuration
        )
        if naturalEyeRest {
            resetEyeCycleAfterNaturalRest(at: date)
            if let guidanceSchedule {
                self.guidanceSchedule = schedulePolicy.resettingEyeCycle(
                    in: guidanceSchedule
                )
            }
        }

        if let suspendedSchedule {
            nextDue = schedulePolicy.restore(
                suspendedSchedule,
                preserving: nextDue,
                at: date,
                systemInactivity: systemInactivity.accumulatedDuration
            )
            updateDeferredIntervalRemaining(
                schedulePolicy.intervalRemaining(
                    in: suspendedSchedule,
                    systemInactivity: systemInactivity.accumulatedDuration
                )
            )
        }

        // Guidance is the innermost freeze. If a quiet guide expires across a
        // date boundary, let its saved remaining-time snapshot restore last so
        // the outer system-suspension snapshot cannot shorten another kind's
        // remaining work by the portion elapsed before sleep.
        expireStaleQuietReminders(at: date)

        // Only surviving occurrences are delayed. Stale quiet guidance must be
        // evaluated against its original date before `delay` shifts startedAt
        // onto the wake date and accidentally makes yesterday look current.
        if var reminder = activeReminder, !reminder.state.isTerminal {
            do {
                try reminder.send(.delay(by: suspendedDuration), at: date)
                activeReminder = reminder
            } catch {
                record(error)
            }
        }

        // Presentation snapshots are derived from dates rather than business
        // animation state. Moving their anchors preserves the exact frame that
        // was visible before the panel was hidden.
        receiptStartedAt = receiptStartedAt?.addingTimeInterval(suspendedDuration)
        exitAnimationStartedAt = exitAnimationStartedAt?.addingTimeInterval(
            suspendedDuration
        )
        panelPresentationStartedAt = panelPresentationStartedAt?.addingTimeInterval(
            suspendedDuration
        )

        if let remainingAutoDismiss {
            autoDismissAt = date.addingTimeInterval(remainingAutoDismiss)
        }
        if let remainingReceiptDismiss {
            receiptDismissAt = date.addingTimeInterval(remainingReceiptDismiss)
        }
        if let remainingExitAnimationDismiss {
            exitAnimationDismissAt = date.addingTimeInterval(
                remainingExitAnimationDismiss
            )
        }

        let shouldRestorePanel = panelWasVisibleBeforePause
        self.clockSuspensionStartedAt = nil
        systemInactivity.reset()
        suspendedSchedule = nil
        remainingAutoDismiss = nil
        remainingReceiptDismiss = nil
        remainingExitAnimationDismiss = nil
        panelWasVisibleBeforePause = false

        if shouldRestorePanel {
            showPanel(userInitiated: userInitiated)
            updatePanelInteractionPause()
        }
    }

    private func restoreGuidanceSchedule(at date: Date) {
        guard let guidanceSchedule else { return }
        nextDue = reminderSchedulePolicy.restore(
            guidanceSchedule,
            preserving: nextDue,
            at: date,
            systemInactivity: 0
        )
        updateDeferredIntervalRemaining(
            reminderSchedulePolicy.intervalRemaining(
                in: guidanceSchedule,
                systemInactivity: 0
            )
        )
        self.guidanceSchedule = nil
    }

    private func resetEyeCycleAfterNaturalRest(at date: Date) {
        pendingReminders.removeAll { $0.kind == .eye }

        if let reminder = activeReminder,
           reminder.kind == .eye {
            switch reminder.state {
            case .guided, .completed, .skipped, .emergencySkip:
                break
            default:
                discardActivePresentation()
            }
        }

        if exitAnimation?.kind == .eye {
            discardExitAnimation()
        }

        let hasActiveEyeGuidance: Bool
        if activeReminder?.kind == .eye,
           case .guided = activeReminder?.state {
            hasActiveEyeGuidance = true
        } else {
            hasActiveEyeGuidance = false
        }

        if lastSettings.eyeEnabled, !hasActiveEyeGuidance,
           let fullInterval = intervalDuration(for: .eye) {
            setNextDue(
                nextDate(
                    afterActiveWork: fullInterval,
                    resumingAt: date
                ),
                for: .eye,
                intervalRemaining: fullInterval
            )
        } else if !lastSettings.eyeEnabled {
            setNextDue(nil, for: .eye)
        }
    }

    private func expireStaleQuietReminders(at date: Date) {
        let calendar = schedulingCalendar
        var expiredOccurrence = false

        if let quietDue = nextDue[.quietPractice],
           let replacement = reminderSchedulePolicy
            .replacementForStaleQuietDeadline(quietDue, at: date) {
            expiredOccurrence = true
            nextDue[.quietPractice] = lastSettings.quietEnabled
                ? replacement
                : nil
        }

        pendingReminders.removeAll { reminder in
            guard reminder.kind == .quietPractice else { return false }
            let shouldExpire = !calendar.isDate(
                occurrenceReferenceDate(for: reminder),
                inSameDayAs: date
            )
            expiredOccurrence = expiredOccurrence || shouldExpire
            return shouldExpire
        }

        if let reminder = activeReminder,
           reminder.kind == .quietPractice,
           !calendar.isDate(
                occurrenceReferenceDate(for: reminder),
                inSameDayAs: date
           ) {
            expiredOccurrence = true
            if case .guided = reminder.state {
                restoreGuidanceSchedule(at: date)
            }
            discardActivePresentation()
        }

        if exitAnimation?.kind == .quietPractice,
           let exitAnimationStartedAt,
           !calendar.isDate(exitAnimationStartedAt, inSameDayAs: date) {
            expiredOccurrence = true
            discardExitAnimation()
        }

        guard expiredOccurrence else { return }
        if lastSettings.quietEnabled,
           activeReminder?.kind != .quietPractice,
           nextDue[.quietPractice] == nil {
            nextDue[.quietPractice] = nextQuietDate(after: date)
        } else if !lastSettings.quietEnabled {
            nextDue[.quietPractice] = nil
        }
    }

    private func occurrenceReferenceDate(for reminder: ReminderInstance) -> Date {
        switch reminder.state {
        case .scheduled(let dueAt):
            dueAt
        case .firstPresented(let at),
             .followUpPresented(let at),
             .pendingInMenuBar(let at),
             .seriousPresented(let at),
             .completed(let at),
             .skipped(let at),
             .emergencySkip(let at):
            at
        case .retryPending(let retryAt):
            retryAt
        case .guided(let startedAt, _):
            startedAt
        case .snoozed(let until, _):
            until
        }
    }

    private func discardActivePresentation() {
        activeReminder = nil
        activeIsManual = false
        receipt = nil
        receiptStartedAt = nil
        receiptDismissAt = nil
        remainingReceiptDismiss = nil
        autoDismissAt = nil
        remainingAutoDismiss = nil
        discardExitAnimation()
        panelWasVisibleBeforePause = false
        panelController.dismiss()
    }

    private func discardExitAnimation() {
        exitAnimation = nil
        exitAnimationStartedAt = nil
        exitAnimationDismissAt = nil
        remainingExitAnimationDismiss = nil
        if activeReminder == nil, receipt == nil {
            panelWasVisibleBeforePause = false
            panelController.dismiss()
        }
    }

    private var reminderSchedulePolicy: ReminderSchedulePolicy {
        makeReminderSchedulePolicy(calendar: schedulingCalendar)
    }

    private func makeReminderSchedulePolicy(
        calendar: Calendar
    ) -> ReminderSchedulePolicy {
        ReminderSchedulePolicy(
            configuration: ReminderSchedulePolicy.Configuration(
                eyeInterval: TimeInterval(
                    max(1, lastSettings.eyeIntervalMinutes) * 60
                ),
                standingInterval: TimeInterval(
                    max(1, lastSettings.standingIntervalMinutes) * 60
                ),
                quietDailyCount: lastSettings.quietDailyCount,
                workdayStartHour: lastSettings.workdayStartHour,
                workdayEndHour: lastSettings.workdayEndHour
            ),
            calendar: calendar
        )
    }

    private func intervalDuration(for kind: ReminderKind) -> TimeInterval? {
        reminderSchedulePolicy.intervalDuration(for: kind)
    }

    private func updateDeferredIntervalRemaining(
        _ remaining: [ReminderKind: TimeInterval]
    ) {
        for kind in [ReminderKind.eye, .standing] {
            guard nextDue[kind] != nil else {
                deferredIntervalRemaining[kind] = nil
                continue
            }
            if let duration = remaining[kind] {
                deferredIntervalRemaining[kind] = max(0, duration)
            }
        }
    }

    private func setNextDue(
        _ date: Date?,
        for kind: ReminderKind,
        intervalRemaining: TimeInterval? = nil
    ) {
        nextDue[kind] = date
        guard kind == .eye || kind == .standing else { return }

        guard date != nil else {
            deferredIntervalRemaining[kind] = nil
            return
        }
        deferredIntervalRemaining[kind] = max(
            0,
            intervalRemaining ?? intervalDuration(for: kind) ?? 0
        )
    }

    private func nextDate(
        afterActiveWork remaining: TimeInterval,
        resumingAt date: Date
    ) -> Date {
        reminderSchedulePolicy.nextDate(
            afterActiveWork: remaining,
            resumingAt: date
        )
    }

    private func installWorkspaceSuspensionObservers() {
        let notificationCenter = NSWorkspace.shared.notificationCenter
        workspaceObservers.store([
            notificationCenter.addObserver(
                forName: NSWorkspace.willSleepNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.beginSystemSuspension(.systemSleep)
                }
            },
            notificationCenter.addObserver(
                forName: NSWorkspace.didWakeNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.endSystemSuspension(.systemSleep)
                }
            },
            notificationCenter.addObserver(
                forName: NSWorkspace.screensDidSleepNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.beginSystemSuspension(.screenSleep)
                }
            },
            notificationCenter.addObserver(
                forName: NSWorkspace.screensDidWakeNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.endSystemSuspension(.screenSleep)
                }
            },
            notificationCenter.addObserver(
                forName: NSWorkspace.sessionDidResignActiveNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.beginSystemSuspension(.sessionInactive)
                }
            },
            notificationCenter.addObserver(
                forName: NSWorkspace.sessionDidBecomeActiveNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.endSystemSuspension(.sessionInactive)
                }
            },
        ])
    }

    private func installSystemTimeObservers() {
        let notificationCenter = NotificationCenter.default
        systemTimeObservers.store([
            notificationCenter.addObserver(
                forName: .NSSystemClockDidChange,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    _ = self?.observeCurrentWallClock(
                        forceCalendarRebase: true
                    )
                }
            },
            notificationCenter.addObserver(
                forName: .NSSystemTimeZoneDidChange,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    _ = self?.observeCurrentWallClock(
                        forceCalendarRebase: true
                    )
                }
            },
        ])
    }

    private func beginSystemSuspension(_ reason: ClockSuspensionReason) {
        let eventDate = observeCurrentWallClock()
        guard !systemInactivity.contains(reason) else { return }
        beginClockSuspensionIfNeeded(at: eventDate)
        systemInactivity.begin(reason, at: eventDate)
    }

    private func endSystemSuspension(_ reason: ClockSuspensionReason) {
        let eventDate = observeCurrentWallClock()
        guard systemInactivity.end(reason, at: eventDate) else { return }

        if let pausedUntil, pausedUntil <= eventDate {
            self.pausedUntil = nil
            manualPauseIntent = nil
        }
        finishClockSuspensionIfPossible(at: eventDate, userInitiated: false)
    }

    private func presentPanel(
        autoDismissAfter timeout: TimeInterval?,
        userInitiated: Bool
    ) {
        panelPresentationStartedAt = now
        if let timeout, !NSWorkspace.shared.isVoiceOverEnabled {
            autoDismissAt = now.addingTimeInterval(timeout)
        } else {
            autoDismissAt = nil
        }
        remainingAutoDismiss = nil
        showPanel(userInitiated: userInitiated)
        updatePanelInteractionPause()

        if !userInitiated {
            announceCurrentReminder()
        }
    }

    private func showPanel(userInitiated: Bool) {
        let isSerious: Bool
        if case .seriousPresented = activeReminder?.state {
            isSerious = true
        } else {
            isSerious = false
        }

        let shouldTakeFocus = userInitiated
            || isSerious
            || NSWorkspace.shared.isVoiceOverEnabled

        panelController.show(
            presentation: isSerious ? .serious : .compact,
            userInitiated: shouldTakeFocus,
            seriousEmergencyAction: { [weak self] in
                self?.emergencySkip()
            }
        ) {
            ReminderCardView(model: self)
        }
    }

    private func announceCurrentReminder() {
        guard let reminder = activeReminder else { return }
        let announcement: String
        if case .seriousPresented = reminder.state {
            announcement = "\(reminder.kind.displayName)认真模式。按 Return 开始，按 Escape 紧急跳过。"
        } else {
            announcement = "\(reminder.kind.displayName)提醒。请选择开始、稍后或本次跳过。"
        }
        NSAccessibility.post(
            element: NSApp as Any,
            notification: .announcementRequested,
            userInfo: [
                .announcement: announcement,
                .priority: NSAccessibilityPriorityLevel.medium.rawValue,
            ]
        )
    }

    private func showReceipt(_ nextReceipt: PanelReceipt, keepReminder: Bool) {
        receipt = nextReceipt
        receiptStartedAt = now
        remainingReceiptDismiss = nil
        receiptDismissAt = NSWorkspace.shared.isVoiceOverEnabled
            ? nil
            : now.addingTimeInterval(receiptDisplayDuration(nextReceipt))
        autoDismissAt = nil
        showPanel(userInitiated: nextReceipt != .completed)
        updatePanelInteractionPause()

        if let reminder = activeReminder,
           reminder.state.isTerminal,
           !activeIsManual {
            setNextDue(
                nextScheduledDate(
                    for: reminder.kind,
                    after: now
                ),
                for: reminder.kind
            )
            // Commit the next recurrence before the visual receipt finishes.
            activeIsManual = true
        }

        if !keepReminder, activeReminder?.state.isTerminal != true {
            activeReminder = nil
        }
    }

    private func finishReceipt() {
        receiptDismissAt = nil
        remainingReceiptDismiss = nil
        receipt = nil
        receiptStartedAt = nil
        panelController.dismiss()

        guard let reminder = activeReminder else { return }
        if reminder.state.isTerminal {
            activeReminder = nil
            activeIsManual = false
        }
    }

    private func receiptDisplayDuration(_ receipt: PanelReceipt) -> TimeInterval {
        switch receipt {
        case .completed:
            6.5
        case .snoozed, .skipped, .endedEarly, .emergencySkipped:
            5.0
        }
    }

    private func beginExitAnimation(
        _ animation: PanelExitAnimation,
        forceCompact: Bool
    ) {
        exitAnimation = animation
        exitAnimationStartedAt = now
        exitAnimationDismissAt = now.addingTimeInterval(0.42)
        autoDismissAt = nil
        remainingAutoDismiss = nil

        if forceCompact || !panelController.isVisible {
            showPanel(userInitiated: false)
        }
    }

    private func finishExitAnimation() {
        exitAnimationDismissAt = nil
        exitAnimationStartedAt = nil
        exitAnimation = nil
        panelController.dismiss()
    }

    private func presentationTimeout(for state: ReminderState) -> TimeInterval? {
        switch state {
        case .firstPresented:
            8
        case .followUpPresented:
            10
        case .seriousPresented:
            15
        default:
            nil
        }
    }

    private func rebuildSchedule(from date: Date) {
        var schedule: [ReminderKind: Date] = [:]
        if lastSettings.eyeEnabled {
            schedule[.eye] = nextIntervalDate(
                minutes: lastSettings.eyeIntervalMinutes,
                after: date
            )
        }
        if lastSettings.standingEnabled {
            schedule[.standing] = nextIntervalDate(
                minutes: lastSettings.standingIntervalMinutes,
                after: date
            )
        }
        if lastSettings.quietEnabled {
            schedule[.quietPractice] = nextQuietDate(after: date)
        }
        nextDue = schedule
        deferredIntervalRemaining.removeAll()
        for kind in [ReminderKind.eye, .standing] where schedule[kind] != nil {
            deferredIntervalRemaining[kind] = intervalDuration(for: kind)
        }
    }

    private func reconcileSchedule(
        previous: RuntimeSettings,
        current: RuntimeSettings,
        from date: Date
    ) {
        let workdayChanged = previous.workdayStartHour != current.workdayStartHour
            || previous.workdayEndHour != current.workdayEndHour

        if !current.eyeEnabled {
            setNextDue(nil, for: .eye)
        } else if !previous.eyeEnabled
                    || previous.eyeIntervalMinutes != current.eyeIntervalMinutes
                    || workdayChanged {
            setNextDue(
                nextIntervalDate(
                    minutes: current.eyeIntervalMinutes,
                    after: date
                ),
                for: .eye,
                intervalRemaining: TimeInterval(
                    current.eyeIntervalMinutes * 60
                )
            )
        }

        if !current.standingEnabled {
            setNextDue(nil, for: .standing)
        } else if !previous.standingEnabled
                    || previous.standingIntervalMinutes != current.standingIntervalMinutes
                    || workdayChanged {
            setNextDue(
                nextIntervalDate(
                    minutes: current.standingIntervalMinutes,
                    after: date
                ),
                for: .standing,
                intervalRemaining: TimeInterval(
                    current.standingIntervalMinutes * 60
                )
            )
        }

        let quietCadenceChanged = previous.quietDailyCount != current.quietDailyCount
            || workdayChanged
        if !current.quietEnabled {
            nextDue[.quietPractice] = nil
        } else if !previous.quietEnabled || quietCadenceChanged {
            nextDue[.quietPractice] = nextQuietDate(after: date)
        }
    }

    private func nextScheduledDate(for kind: ReminderKind, after date: Date) -> Date? {
        switch kind {
        case .eye where lastSettings.eyeEnabled:
            nextIntervalDate(
                minutes: lastSettings.eyeIntervalMinutes,
                after: date
            )
        case .standing where lastSettings.standingEnabled:
            nextIntervalDate(
                minutes: lastSettings.standingIntervalMinutes,
                after: date
            )
        case .quietPractice where lastSettings.quietEnabled:
            nextQuietDate(after: date)
        default:
            nil
        }
    }

    private func nextIntervalDate(minutes: Int, after date: Date) -> Date {
        let calendar = schedulingCalendar
        let base: Date

        if isWithinWorkday(date) {
            base = date
        } else {
            base = nextWorkdayStart(after: date, includeTodayIfBeforeStart: true)
        }

        let candidate = base.addingTimeInterval(TimeInterval(minutes * 60))
        let endOfCandidateDay = calendar.date(
            bySettingHour: lastSettings.workdayEndHour,
            minute: 0,
            second: 0,
            of: candidate
        ) ?? candidate

        if !calendar.isDateInWeekend(candidate), candidate < endOfCandidateDay {
            return candidate
        }

        return nextWorkdayStart(
            after: candidate,
            includeTodayIfBeforeStart: false
        ).addingTimeInterval(TimeInterval(minutes * 60))
    }

    private func nextQuietDate(after date: Date) -> Date {
        reminderSchedulePolicy.nextQuietDate(after: date)
    }

    private func isWithinWorkday(_ date: Date) -> Bool {
        reminderSchedulePolicy.isWithinWorkday(date)
    }

    private func nextWorkdayStart(
        after date: Date,
        includeTodayIfBeforeStart: Bool
    ) -> Date {
        reminderSchedulePolicy.nextWorkdayStart(
            after: date,
            includeTodayIfBeforeStart: includeTodayIfBeforeStart
        )
    }

    private func record(_ error: Error) {
        lastError = String(describing: error)
        autoDismissAt = nil
    }

    private static func registerDefaults() {
        AppSettings.registerDefaults()
    }

    private static func readSettings() -> RuntimeSettings {
        let defaults = UserDefaults.standard
        return RuntimeSettings(
            eyeEnabled: defaults.bool(forKey: SettingsKey.eyeReminderEnabled),
            eyeIntervalMinutes: max(1, defaults.integer(forKey: SettingsKey.eyeIntervalMinutes)),
            standingEnabled: defaults.bool(forKey: SettingsKey.standReminderEnabled),
            standingIntervalMinutes: max(1, defaults.integer(forKey: SettingsKey.standIntervalMinutes)),
            quietEnabled: defaults.bool(forKey: SettingsKey.quietReminderEnabled),
            quietDailyCount: max(1, defaults.integer(forKey: SettingsKey.quietDailyCount)),
            seriousMode: defaults.bool(forKey: SettingsKey.seriousModeEnabled),
            workdayStartHour: defaults.integer(forKey: SettingsKey.workdayStartHour),
            workdayEndHour: defaults.integer(forKey: SettingsKey.workdayEndHour)
        )
    }
}
