import Darwin
import Foundation

enum DebugLogger {
    static let isEnabled: Bool = {
        guard let value = ProcessInfo.processInfo.environment["MOODBREAK_DEBUG"]?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() else {
            return true
        }
        return !["0", "false", "off", "no"].contains(value)
    }()

    static func log(_ category: String, _ message: String) {
        guard isEnabled else {
            return
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let timestamp = formatter.string(from: Date())
        print("[MoodBreak][\(timestamp)][\(category)] \(message)")
        fflush(stdout)
    }
}
