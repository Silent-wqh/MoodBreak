import AppKit
import Foundation

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let config = AppConfig.fromEnvironment()
    private var activityMonitor: ActivityMonitor!
    private let storage = Storage()
    private var notificationController: NotificationController!
    private let menuBarController = MenuBarController()

    private var scheduler: Scheduler!
    private var timer: Timer?
    private var lastSnapshot = ActivitySnapshot(state: .active, idleSeconds: 0, timestamp: Date())
    private var lastSavedMuteUntil: Date?
    private var lastLoggedActivityState: ActivityState?
    private var tickCounter = 0

    func applicationDidFinishLaunching(_ notification: Notification) {
        notificationController = NotificationController(
            snoozeShortSec: config.snoozeShortSec,
            snoozeMediumSec: config.snoozeMediumSec,
            snoozeLongSec: config.snoozeLongSec,
            reminderTimeoutSec: config.reminderTimeoutSec
        )
        activityMonitor = ActivityMonitor(idleThresholdSec: config.idleThresholdSec)

        let muteUntil = storage.loadMuteUntil()
        scheduler = Scheduler(
            intervalSec: config.intervalSec,
            idleThresholdSec: config.idleThresholdSec,
            snoozeShortSec: config.snoozeShortSec,
            snoozeMediumSec: config.snoozeMediumSec,
            snoozeLongSec: config.snoozeLongSec,
            muteUntil: muteUntil,
            now: Date()
        )
        lastSavedMuteUntil = muteUntil

        DebugLogger.log(
            "App",
            "Launch. testMode=\(config.isTestMode) interval=\(Int(scheduler.state.intervalSec))s idleThreshold=\(Int(scheduler.state.idleThresholdSec))s snooze=\(Int(config.snoozeShortSec))/\(Int(config.snoozeMediumSec))/\(Int(config.snoozeLongSec))s muteUntil=\(muteUntil?.description ?? "nil")"
        )

        bindControllers()
        menuBarController.setTestMode(config.isTestMode)
        startTicking()
        refreshMenu()

        notificationController.requestAuthorization { [weak self] _ in
            DebugLogger.log(
                "Notify",
                "Authorization refresh done. status=\(self?.notificationController.authorizationStatus.rawValue ?? -1)"
            )
            self?.refreshMenu()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        DebugLogger.log("App", "Terminate.")
        timer?.invalidate()
        timer = nil
    }

    private func bindControllers() {
        notificationController.onAction = { [weak self] action in
            DebugLogger.log("Action", "Received action=\(String(describing: action))")
            self?.handleReminderAction(action)
        }
        notificationController.onAuthorizationStatusChange = { [weak self] _ in
            DebugLogger.log(
                "Notify",
                "Authorization changed. status=\(self?.notificationController.authorizationStatus.rawValue ?? -1)"
            )
            self?.refreshMenu()
        }

        menuBarController.onTestNotify = { [weak self] in
            guard let self else { return }
            DebugLogger.log("Menu", "Click Test Notify")
            if self.notificationController.canSendInteractiveReminder() {
                self.notificationController.sendReminder()
            }
            self.refreshMenu()
        }

        menuBarController.onTogglePause = { [weak self] in
            guard let self else { return }
            if self.scheduler.state.isPaused {
                self.scheduler.resume()
                DebugLogger.log("Menu", "Click Resume Reminders")
            } else {
                self.scheduler.pause()
                DebugLogger.log("Menu", "Click Pause Reminders")
            }
            self.refreshMenu()
        }

        menuBarController.onToggleMute = { [weak self] in
            guard let self else { return }
            if self.scheduler.isMuted(at: Date()) {
                self.scheduler.clearMute(now: Date())
                DebugLogger.log("Menu", "Click Unmute Today")
            } else {
                self.scheduler.handle(.muteToday, now: Date())
                DebugLogger.log("Menu", "Click Mute Today")
            }
            self.persistMuteIfNeeded()
            self.refreshMenu()
        }

        menuBarController.onQuit = {
            DebugLogger.log("Menu", "Click Quit")
            NSApplication.shared.terminate(nil)
        }
    }

    private func startTicking() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(
            timeInterval: 1,
            target: self,
            selector: #selector(handleTick),
            userInfo: nil,
            repeats: true
        )
        if let timer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    @objc
    private func handleTick() {
        tick()
    }

    private func tick() {
        let now = Date()
        lastSnapshot = activityMonitor.snapshot(now: now)
        tickCounter += 1

        if lastLoggedActivityState != lastSnapshot.state {
            DebugLogger.log(
                "Activity",
                "State changed to \(lastSnapshot.state == .active ? "active" : "idle"), idleSeconds=\(String(format: "%.1f", lastSnapshot.idleSeconds))"
            )
            lastLoggedActivityState = lastSnapshot.state
        }

        if tickCounter % 30 == 0 {
            DebugLogger.log(
                "Tick",
                "work=\(Int(scheduler.state.workTimeSec))s pending=\(scheduler.state.hasPendingReminder) paused=\(scheduler.state.isPaused) muted=\(scheduler.isMuted(at: now)) nextFire=\(scheduler.state.nextFireTime?.description ?? "nil")"
            )
        }

        let event = scheduler.tick(now: now, activity: lastSnapshot.state)

        if case .triggerReminder = event {
            DebugLogger.log(
                "Scheduler",
                "triggerReminder. work=\(Int(scheduler.state.workTimeSec))s activity=\(lastSnapshot.state == .active ? "active" : "idle")"
            )
            if notificationController.canSendInteractiveReminder() {
                notificationController.sendReminder()
            } else {
                // Permission is required in this MVP. Fall back to auto-snooze to avoid scheduler lock.
                DebugLogger.log("Scheduler", "Cannot send reminder, fallback dismiss->short-snooze")
                scheduler.handle(.dismiss, now: now)
            }
        }

        persistMuteIfNeeded()
        refreshMenu()
    }

    private func handleReminderAction(_ action: ReminderAction) {
        let now = Date()
        scheduler.handle(action, now: now)
        DebugLogger.log(
            "Scheduler",
            "Handled action=\(String(describing: action)). work=\(Int(scheduler.state.workTimeSec))s nextFire=\(scheduler.state.nextFireTime?.description ?? "nil") muteUntil=\(scheduler.state.muteUntil?.description ?? "nil")"
        )
        persistMuteIfNeeded()
        refreshMenu()
    }

    private func persistMuteIfNeeded() {
        let current = scheduler.state.muteUntil
        if current != lastSavedMuteUntil {
            storage.saveMuteUntil(current)
            DebugLogger.log("Storage", "Persist mute_until=\(current?.description ?? "nil")")
            lastSavedMuteUntil = current
        }
    }

    private func refreshMenu() {
        menuBarController.update(
            activity: lastSnapshot,
            schedulerState: scheduler.state,
            warningText: notificationController.currentReminderModeText(),
            showWarning: notificationController.shouldShowWarningInMenu()
        )
    }
}
