import CoreGraphics
import Foundation

final class ActivityMonitor {
    private static let anyInputEventType = CGEventType(rawValue: UInt32.max) ?? .null

    private let idleThresholdSec: TimeInterval

    init(idleThresholdSec: TimeInterval = 5 * 60) {
        self.idleThresholdSec = idleThresholdSec
    }

    func snapshot(now: Date = Date()) -> ActivitySnapshot {
        let idleSeconds = CGEventSource.secondsSinceLastEventType(
            .combinedSessionState,
            eventType: Self.anyInputEventType
        )
        let state: ActivityState = idleSeconds >= idleThresholdSec ? .idle : .active

        return ActivitySnapshot(
            state: state,
            idleSeconds: idleSeconds,
            timestamp: now
        )
    }
}
