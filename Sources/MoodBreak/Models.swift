import Foundation

enum ActivityState: Equatable {
    case active
    case idle
}

struct ActivitySnapshot: Equatable {
    let state: ActivityState
    let idleSeconds: TimeInterval
    let timestamp: Date
}

enum ReminderAction: Equatable {
    case restNow
    case snooze5
    case snooze10
    case snooze20
    case skip
    case muteToday
    case dismiss
}

struct SchedulerState: Equatable {
    var workTimeSec: TimeInterval
    let intervalSec: TimeInterval
    let idleThresholdSec: TimeInterval
    var nextFireTime: Date?
    var muteUntil: Date?
    var isPaused: Bool
    var hasPendingReminder: Bool
}

enum SchedulerEvent: Equatable {
    case none
    case triggerReminder
}
