import AppKit
import Foundation

@MainActor
final class ReminderPanelController: NSObject, NSWindowDelegate {
    var onAction: ((ReminderAction) -> Void)?

    private var windowRef: NSWindow?
    private var didEmitAction = false
    private var dismissWorkItem: DispatchWorkItem?
    private var snoozeShortLabel = "Snooze 5m"
    private var snoozeMediumLabel = "Snooze 10m"
    private var snoozeLongLabel = "Snooze 20m"
    private var autoDismissSec: TimeInterval = 60

    func configure(
        snoozeShortSec: TimeInterval,
        snoozeMediumSec: TimeInterval,
        snoozeLongSec: TimeInterval,
        autoDismissSec: TimeInterval
    ) {
        snoozeShortLabel = "Snooze \(AppConfig.shortDurationText(snoozeShortSec))"
        snoozeMediumLabel = "Snooze \(AppConfig.shortDurationText(snoozeMediumSec))"
        snoozeLongLabel = "Snooze \(AppConfig.shortDurationText(snoozeLongSec))"
        self.autoDismissSec = autoDismissSec
    }

    func present() {
        if let windowRef {
            DebugLogger.log("Popup", "Bring existing reminder window to front")
            windowRef.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        didEmitAction = false
        let window = buildWindow()
        windowRef = window
        window.delegate = self
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        DebugLogger.log("Popup", "Present reminder window")
        scheduleAutoDismiss(after: autoDismissSec)
    }

    func windowWillClose(_ notification: Notification) {
        dismissWorkItem?.cancel()
        dismissWorkItem = nil
        windowRef = nil

        if !didEmitAction {
            didEmitAction = true
            DebugLogger.log("Popup", "Window closed without action -> dismiss")
            onAction?(.dismiss)
        }
    }

    private func buildWindow() -> NSWindow {
        let frame = NSRect(x: 0, y: 0, width: 360, height: 220)
        let window = NSPanel(
            contentRect: frame,
            styleMask: [.titled, .closable, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.level = .floating
        window.title = "MoodBreak"
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let root = NSView(frame: frame)
        root.translatesAutoresizingMaskIntoConstraints = false
        window.contentView = root

        let title = NSTextField(labelWithString: "Time to take a short break")
        title.font = .systemFont(ofSize: 15, weight: .semibold)
        title.alignment = .center
        title.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(title)

        let topRow = NSStackView(views: [
            makeButton(title: "Rest Now", action: #selector(tapRestNow)),
            makeButton(title: "Skip", action: #selector(tapSkip))
        ])
        topRow.orientation = .horizontal
        topRow.distribution = .fillEqually
        topRow.spacing = 8
        topRow.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(topRow)

        let middleRow = NSStackView(views: [
            makeButton(title: snoozeShortLabel, action: #selector(tapSnooze5)),
            makeButton(title: snoozeMediumLabel, action: #selector(tapSnooze10)),
            makeButton(title: snoozeLongLabel, action: #selector(tapSnooze20))
        ])
        middleRow.orientation = .horizontal
        middleRow.distribution = .fillEqually
        middleRow.spacing = 8
        middleRow.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(middleRow)

        let bottomRow = NSStackView(views: [
            makeButton(title: "Mute Today", action: #selector(tapMuteToday))
        ])
        bottomRow.orientation = .horizontal
        bottomRow.distribution = .fillEqually
        bottomRow.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(bottomRow)

        NSLayoutConstraint.activate([
            title.topAnchor.constraint(equalTo: root.topAnchor, constant: 20),
            title.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 16),
            title.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -16),

            topRow.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 18),
            topRow.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 16),
            topRow.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -16),
            topRow.heightAnchor.constraint(equalToConstant: 30),

            middleRow.topAnchor.constraint(equalTo: topRow.bottomAnchor, constant: 10),
            middleRow.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 16),
            middleRow.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -16),
            middleRow.heightAnchor.constraint(equalToConstant: 30),

            bottomRow.topAnchor.constraint(equalTo: middleRow.bottomAnchor, constant: 10),
            bottomRow.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 16),
            bottomRow.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -16),
            bottomRow.heightAnchor.constraint(equalToConstant: 30)
        ])

        return window
    }

    private func makeButton(title: String, action: Selector) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        button.bezelStyle = .rounded
        button.setButtonType(.momentaryPushIn)
        return button
    }

    private func emitAndClose(_ action: ReminderAction) {
        guard !didEmitAction else {
            return
        }
        didEmitAction = true
        dismissWorkItem?.cancel()
        dismissWorkItem = nil
        DebugLogger.log("Popup", "User selected action=\(String(describing: action))")
        onAction?(action)
        windowRef?.close()
    }

    private func scheduleAutoDismiss(after seconds: TimeInterval = 60) {
        dismissWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            DebugLogger.log("Popup", "Auto timeout -> dismiss")
            self.emitAndClose(.dismiss)
        }
        dismissWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: work)
    }

    @objc
    private func tapRestNow() {
        emitAndClose(.restNow)
    }

    @objc
    private func tapSnooze5() {
        emitAndClose(.snooze5)
    }

    @objc
    private func tapSnooze10() {
        emitAndClose(.snooze10)
    }

    @objc
    private func tapSnooze20() {
        emitAndClose(.snooze20)
    }

    @objc
    private func tapSkip() {
        emitAndClose(.skip)
    }

    @objc
    private func tapMuteToday() {
        emitAndClose(.muteToday)
    }
}
