import Foundation
import Testing
@testable import MoodBreak

struct SchedulerTests {
    @Test
    func activeAccumulatesAndIdlePauses() {
        let t0 = fixedDate("2026-02-28T10:00:00Z")
        let scheduler = Scheduler(intervalSec: 10_000, now: t0)

        _ = scheduler.tick(now: t0.addingTimeInterval(30), activity: .active)
        #expect(scheduler.state.workTimeSec == 30)

        _ = scheduler.tick(now: t0.addingTimeInterval(90), activity: .idle)
        #expect(scheduler.state.workTimeSec == 30)

        _ = scheduler.tick(now: t0.addingTimeInterval(120), activity: .active)
        #expect(scheduler.state.workTimeSec == 60)
    }

    @Test
    func triggersAtIntervalAndWaitsForResponse() {
        let t0 = fixedDate("2026-02-28T10:00:00Z")
        let scheduler = Scheduler(intervalSec: 60, now: t0)

        let event = scheduler.tick(now: t0.addingTimeInterval(60), activity: .active)
        #expect(event == .triggerReminder)
        #expect(scheduler.state.hasPendingReminder)

        let followUp = scheduler.tick(now: t0.addingTimeInterval(80), activity: .active)
        #expect(followUp == .none)
        #expect(scheduler.state.workTimeSec == 60)
    }

    @Test
    func restAndSkipResetWorkTime() {
        let t0 = fixedDate("2026-02-28T10:00:00Z")
        let scheduler = Scheduler(intervalSec: 60, now: t0)

        _ = scheduler.tick(now: t0.addingTimeInterval(60), activity: .active)
        scheduler.handle(.restNow, now: t0.addingTimeInterval(60))
        #expect(scheduler.state.workTimeSec == 0)
        #expect(scheduler.state.nextFireTime == nil)
        #expect(!scheduler.state.hasPendingReminder)

        _ = scheduler.tick(now: t0.addingTimeInterval(120), activity: .active)
        #expect(scheduler.state.hasPendingReminder)
        scheduler.handle(.skip, now: t0.addingTimeInterval(120))
        #expect(scheduler.state.workTimeSec == 0)
    }

    @Test
    func snoozeUsesNextFireTimePriority() {
        let t0 = fixedDate("2026-02-28T10:00:00Z")
        let scheduler = Scheduler(intervalSec: 60, now: t0)

        _ = scheduler.tick(now: t0.addingTimeInterval(60), activity: .active)
        scheduler.handle(.snooze10, now: t0.addingTimeInterval(60))

        let beforeDue = scheduler.tick(now: t0.addingTimeInterval(8 * 60), activity: .active)
        #expect(beforeDue == .none)

        let onDue = scheduler.tick(now: t0.addingTimeInterval(11 * 60), activity: .active)
        #expect(onDue == .triggerReminder)
    }

    @Test
    func idleDelaysReminderUntilBackToActive() {
        let t0 = fixedDate("2026-02-28T10:00:00Z")
        let scheduler = Scheduler(intervalSec: 60, now: t0)

        _ = scheduler.tick(now: t0.addingTimeInterval(60), activity: .active)
        scheduler.handle(.snooze5, now: t0.addingTimeInterval(60))

        let dueButIdle = scheduler.tick(now: t0.addingTimeInterval(6 * 60), activity: .idle)
        #expect(dueButIdle == .none)
        #expect(!scheduler.state.hasPendingReminder)

        let backActive = scheduler.tick(now: t0.addingTimeInterval(6 * 60 + 1), activity: .active)
        #expect(backActive == .triggerReminder)
        #expect(scheduler.state.hasPendingReminder)
    }

    @Test
    func dismissActsAsSnooze5Minutes() {
        let t0 = fixedDate("2026-02-28T10:00:00Z")
        let scheduler = Scheduler(intervalSec: 60, now: t0)

        scheduler.handle(.dismiss, now: t0)
        #expect(scheduler.state.nextFireTime == t0.addingTimeInterval(5 * 60))
    }

    @Test
    func muteTodaySuppressesAndAutoRecoversNextDay() {
        let calendar = utcCalendar()
        let t0 = fixedDate("2026-02-28T10:00:00Z")
        let scheduler = Scheduler(
            intervalSec: 48 * 60 * 60,
            muteUntil: nil,
            now: t0,
            calendar: calendar
        )

        scheduler.handle(.muteToday, now: t0)
        #expect(scheduler.isMuted(at: t0))
        #expect(scheduler.state.muteUntil == fixedDate("2026-03-01T00:00:00Z"))

        _ = scheduler.tick(now: t0.addingTimeInterval(120), activity: .active)
        #expect(scheduler.state.workTimeSec == 0)

        _ = scheduler.tick(now: fixedDate("2026-03-01T00:00:10Z"), activity: .idle)
        #expect(scheduler.state.muteUntil == nil)
    }

    private func fixedDate(_ value: String) -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: value)!
    }

    private func utcCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }
}
