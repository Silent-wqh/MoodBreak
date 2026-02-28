import Foundation

struct AppConfig {
    let isTestMode: Bool
    let intervalSec: TimeInterval
    let idleThresholdSec: TimeInterval
    let snoozeShortSec: TimeInterval
    let snoozeMediumSec: TimeInterval
    let snoozeLongSec: TimeInterval
    let reminderTimeoutSec: TimeInterval

    static func fromEnvironment(
        _ environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> AppConfig {
        let isTestMode = parseBool(environment["MOODBREAK_TEST_MODE"])

        if isTestMode {
            return AppConfig(
                isTestMode: true,
                intervalSec: 60,
                idleThresholdSec: 20,
                snoozeShortSec: 10,
                snoozeMediumSec: 20,
                snoozeLongSec: 30,
                reminderTimeoutSec: 20
            )
        }

        return AppConfig(
            isTestMode: false,
            intervalSec: 25 * 60,
            idleThresholdSec: 5 * 60,
            snoozeShortSec: 5 * 60,
            snoozeMediumSec: 10 * 60,
            snoozeLongSec: 20 * 60,
            reminderTimeoutSec: 60
        )
    }

    static func shortDurationText(_ seconds: TimeInterval) -> String {
        let total = max(1, Int(seconds.rounded()))
        if total < 60 {
            return "\(total)s"
        }

        let minutes = total / 60
        let remainder = total % 60
        if remainder == 0 {
            return "\(minutes)m"
        }
        return "\(minutes)m\(remainder)s"
    }

    private static func parseBool(_ raw: String?) -> Bool {
        guard let raw else {
            return false
        }

        switch raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "1", "true", "on", "yes", "y":
            return true
        default:
            return false
        }
    }
}
