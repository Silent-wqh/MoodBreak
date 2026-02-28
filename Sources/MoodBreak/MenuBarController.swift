import AppKit
import Foundation

@MainActor
final class MenuBarController: NSObject {
    var onTestNotify: (() -> Void)?
    var onTogglePause: (() -> Void)?
    var onToggleMute: (() -> Void)?
    var onQuit: (() -> Void)?

    private let statusItem: NSStatusItem
    private let menu = NSMenu()

    private let activityItem = NSMenuItem(title: "Activity: --", action: nil, keyEquivalent: "")
    private let workTimeItem = NSMenuItem(title: "Work Time: --", action: nil, keyEquivalent: "")
    private let statusItemText = NSMenuItem(title: "Status: --", action: nil, keyEquivalent: "")
    private let modeItem = NSMenuItem(title: "Mode: --", action: nil, keyEquivalent: "")
    private let notificationWarningItem = NSMenuItem(
        title: "Notifications disabled. Enable in System Settings.",
        action: nil,
        keyEquivalent: ""
    )
    private let testNotifyItem = NSMenuItem(title: "Test Notify", action: nil, keyEquivalent: "")
    private let pauseResumeItem = NSMenuItem(title: "Pause Reminders", action: nil, keyEquivalent: "")
    private let muteItem = NSMenuItem(title: "Mute Today", action: nil, keyEquivalent: "")
    private let quitItem = NSMenuItem(title: "Quit", action: nil, keyEquivalent: "q")

    override init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        setupStatusButton()
        setupMenu()
    }

    func setTestMode(_ isTestMode: Bool) {
        modeItem.title = isTestMode ? "Mode: TEST" : "Mode: NORMAL"
    }

    func update(
        activity: ActivitySnapshot,
        schedulerState: SchedulerState,
        warningText: String?,
        showWarning: Bool
    ) {
        activityItem.title = "Activity: \(activity.state == .active ? "active" : "idle")"
        workTimeItem.title = "Work Time: \(formatDuration(seconds: schedulerState.workTimeSec))"

        let muted = schedulerState.muteUntil.map { Date() < $0 } ?? false
        var stateParts: [String] = []
        if schedulerState.isPaused {
            stateParts.append("paused")
        }
        if muted {
            stateParts.append("muted")
        }
        if schedulerState.hasPendingReminder {
            stateParts.append("waiting-response")
        }
        if stateParts.isEmpty {
            stateParts.append("running")
        }
        statusItemText.title = "Status: \(stateParts.joined(separator: ", "))"

        pauseResumeItem.title = schedulerState.isPaused ? "Resume Reminders" : "Pause Reminders"
        muteItem.title = muted ? "Unmute Today" : "Mute Today"

        if muted, let muteUntil = schedulerState.muteUntil {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            formatter.dateStyle = .none
            muteItem.title = "Unmute (until \(formatter.string(from: muteUntil)))"
        }

        notificationWarningItem.title = warningText ?? ""
        notificationWarningItem.isHidden = !showWarning
    }

    private func setupStatusButton() {
        guard let button = statusItem.button else {
            return
        }

        if let icon = IconLoader.loadStatusIcon() {
            button.image = icon
            button.imagePosition = .imageOnly
        } else {
            button.title = "MB"
        }
    }

    private func setupMenu() {
        [modeItem, activityItem, workTimeItem, statusItemText, notificationWarningItem].forEach {
            $0.isEnabled = false
            menu.addItem($0)
        }

        menu.addItem(.separator())

        testNotifyItem.target = self
        testNotifyItem.action = #selector(handleTestNotify)
        menu.addItem(testNotifyItem)

        pauseResumeItem.target = self
        pauseResumeItem.action = #selector(handlePauseResume)
        menu.addItem(pauseResumeItem)

        muteItem.target = self
        muteItem.action = #selector(handleMuteToggle)
        menu.addItem(muteItem)

        menu.addItem(.separator())

        quitItem.target = self
        quitItem.action = #selector(handleQuit)
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    @objc
    private func handleTestNotify() {
        onTestNotify?()
    }

    @objc
    private func handlePauseResume() {
        onTogglePause?()
    }

    @objc
    private func handleMuteToggle() {
        onToggleMute?()
    }

    @objc
    private func handleQuit() {
        onQuit?()
    }

    private func formatDuration(seconds: TimeInterval) -> String {
        let total = Int(seconds)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60

        if hours > 0 {
            return "\(hours)h \(minutes)m \(secs)s"
        }
        if minutes > 0 {
            return "\(minutes)m \(secs)s"
        }
        return "\(secs)s"
    }
}
