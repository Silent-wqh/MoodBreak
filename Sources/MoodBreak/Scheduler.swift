import Foundation

final class Scheduler {
    private(set) var state: SchedulerState
    private var lastTickTime: Date?
    private let calendar: Calendar
    private let snoozeShortSec: TimeInterval
    private let snoozeMediumSec: TimeInterval
    private let snoozeLongSec: TimeInterval

    init(
        intervalSec: TimeInterval = 25 * 60,
        idleThresholdSec: TimeInterval = 5 * 60,
        snoozeShortSec: TimeInterval = 5 * 60,
        snoozeMediumSec: TimeInterval = 10 * 60,
        snoozeLongSec: TimeInterval = 20 * 60,
        muteUntil: Date? = nil,
        now: Date = Date(),
        calendar: Calendar = .current
    ) {
        self.calendar = calendar
        self.snoozeShortSec = snoozeShortSec
        self.snoozeMediumSec = snoozeMediumSec
        self.snoozeLongSec = snoozeLongSec
        self.state = SchedulerState(
            workTimeSec: 0,
            intervalSec: intervalSec,
            idleThresholdSec: idleThresholdSec,
            nextFireTime: nil,
            muteUntil: muteUntil,
            isPaused: false,
            hasPendingReminder: false
        )
        self.lastTickTime = now
    }

    func tick(now: Date, activity: ActivityState) -> SchedulerEvent {
        clearExpiredMuteIfNeeded(now: now)

        guard let previousTick = lastTickTime else {
            lastTickTime = now
            return .none
        }

        let delta = max(0, now.timeIntervalSince(previousTick))
        lastTickTime = now

        if state.isPaused || state.hasPendingReminder || isMuted(at: now) {
            return .none
        }

        if activity == .active {
            state.workTimeSec += delta
        }

        if let nextFireTime = state.nextFireTime {
            if now >= nextFireTime {
                if activity == .active {
                    state.nextFireTime = nil
                    state.hasPendingReminder = true
                    return .triggerReminder
                }
                return .none
            }
            // Snooze window has higher priority than interval-based triggering.
            return .none
        }

        if state.workTimeSec >= state.intervalSec {
            if activity == .active {
                state.hasPendingReminder = true
                return .triggerReminder
            }
            return .none
        }

        return .none
    }

    func handle(_ action: ReminderAction, now: Date) {
        clearExpiredMuteIfNeeded(now: now)
        state.hasPendingReminder = false

        switch action {
        case .restNow:
            resetRound()
        case .skip:
            resetRound()
        case .snooze5:
            state.nextFireTime = now.addingTimeInterval(snoozeShortSec)
        case .snooze10:
            state.nextFireTime = now.addingTimeInterval(snoozeMediumSec)
        case .snooze20:
            state.nextFireTime = now.addingTimeInterval(snoozeLongSec)
        case .muteToday:
            state.nextFireTime = nil
            state.muteUntil = tomorrowStart(from: now)
        case .dismiss:
            state.nextFireTime = now.addingTimeInterval(snoozeShortSec)
        }
    }

    func pause() {
        state.isPaused = true
    }

    func resume() {
        state.isPaused = false
        lastTickTime = Date()
    }

    func clearMute(now: Date = Date()) {
        if let muteUntil = state.muteUntil, now < muteUntil {
            state.muteUntil = nil
        }
    }

    func isMuted(at now: Date = Date()) -> Bool {
        guard let muteUntil = state.muteUntil else {
            return false
        }
        return now < muteUntil
    }

    private func resetRound() {
        state.workTimeSec = 0
        state.nextFireTime = nil
    }

    private func clearExpiredMuteIfNeeded(now: Date) {
        if let muteUntil = state.muteUntil, now >= muteUntil {
            state.muteUntil = nil
        }
    }

    private func tomorrowStart(from now: Date) -> Date {
        let dayStart = calendar.startOfDay(for: now)
        return calendar.date(byAdding: .day, value: 1, to: dayStart) ?? now
    }
}
