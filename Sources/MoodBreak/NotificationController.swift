import Foundation
import UserNotifications

@MainActor
final class NotificationController: NSObject {
    var onAction: (@MainActor (ReminderAction) -> Void)?
    var onAuthorizationStatusChange: (@MainActor (UNAuthorizationStatus) -> Void)?

    private let center: UNUserNotificationCenter?
    private let reminderPanel = ReminderPanelController()
    private var dismissFallbackWorkItem: DispatchWorkItem?
    private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined
    private let snoozeShortSec: TimeInterval
    private let snoozeMediumSec: TimeInterval
    private let snoozeLongSec: TimeInterval
    private let reminderTimeoutSec: TimeInterval

    private let categoryIdentifier = "moodbreak.reminder"
    private let restActionIdentifier = "moodbreak.action.rest_now"
    private let snooze5ActionIdentifier = "moodbreak.action.snooze_5"
    private let snooze10ActionIdentifier = "moodbreak.action.snooze_10"
    private let snooze20ActionIdentifier = "moodbreak.action.snooze_20"
    private let skipActionIdentifier = "moodbreak.action.skip"
    private let muteTodayActionIdentifier = "moodbreak.action.mute_today"

    init(
        snoozeShortSec: TimeInterval = 5 * 60,
        snoozeMediumSec: TimeInterval = 10 * 60,
        snoozeLongSec: TimeInterval = 20 * 60,
        reminderTimeoutSec: TimeInterval = 60,
        centerProvider: @escaping () -> UNUserNotificationCenter = { .current() }
    ) {
        self.snoozeShortSec = snoozeShortSec
        self.snoozeMediumSec = snoozeMediumSec
        self.snoozeLongSec = snoozeLongSec
        self.reminderTimeoutSec = reminderTimeoutSec

        if Bundle.main.bundleURL.pathExtension.lowercased() == "app" {
            self.center = centerProvider()
            DebugLogger.log("Notify", "Mode=system notification (.app bundle)")
        } else {
            self.center = nil
            DebugLogger.log("Notify", "Mode=in-app popup (swift run/non-app bundle)")
        }
        super.init()
        reminderPanel.configure(
            snoozeShortSec: snoozeShortSec,
            snoozeMediumSec: snoozeMediumSec,
            snoozeLongSec: snoozeLongSec,
            autoDismissSec: reminderTimeoutSec
        )
        reminderPanel.onAction = { [weak self] action in
            DebugLogger.log("Notify", "Popup action=\(String(describing: action))")
            self?.consumeAction(action)
        }

        if let center {
            center.delegate = self
            registerCategories()
            refreshAuthorizationStatus()
        } else {
            authorizationStatus = .authorized
            onAuthorizationStatusChange?(.authorized)
        }
    }

    func requestAuthorization(completion: (@MainActor (Bool) -> Void)? = nil) {
        guard let center else {
            authorizationStatus = .authorized
            onAuthorizationStatusChange?(.authorized)
            DebugLogger.log("Notify", "Authorization skipped (popup mode)")
            completion?(true)
            return
        }

        DebugLogger.log("Notify", "Request authorization")
        center.requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] granted, _ in
            Task { @MainActor in
                self?.refreshAuthorizationStatus {
                    DebugLogger.log("Notify", "Authorization result granted=\(granted)")
                    completion?(granted)
                }
            }
        }
    }

    func refreshAuthorizationStatus(completion: (@MainActor () -> Void)? = nil) {
        guard let center else {
            authorizationStatus = .authorized
            onAuthorizationStatusChange?(.authorized)
            DebugLogger.log("Notify", "Authorization status fixed=authorized (popup mode)")
            completion?()
            return
        }

        center.getNotificationSettings { [weak self] settings in
            let status = settings.authorizationStatus
            Task { @MainActor in
                guard let self else {
                    completion?()
                    return
                }

                self.authorizationStatus = status
                self.onAuthorizationStatusChange?(status)
                DebugLogger.log("Notify", "Authorization status=\(status.rawValue)")
                completion?()
            }
        }
    }

    func canSendInteractiveReminder() -> Bool {
        guard center != nil else {
            return true
        }
        return authorizationStatus == .authorized || authorizationStatus == .provisional
    }

    func currentReminderModeText() -> String {
        if center == nil {
            return "Reminder mode: In-app popup (swift run)"
        }

        if canSendInteractiveReminder() {
            return "Reminder mode: System notification"
        }

        return "Notifications disabled. Enable in System Settings."
    }

    func shouldShowWarningInMenu() -> Bool {
        if center == nil {
            return true
        }
        return !canSendInteractiveReminder()
    }

    func sendReminder() {
        guard canSendInteractiveReminder() else {
            DebugLogger.log("Notify", "Skip send reminder: interactive permission unavailable")
            return
        }

        guard let center else {
            DebugLogger.log("Notify", "Show in-app reminder popup")
            reminderPanel.present()
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "Take a short break"
        content.body = "You have worked for a while. Choose one action."
        content.sound = .default
        content.categoryIdentifier = categoryIdentifier

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let identifier = "moodbreak.reminder.\(UUID().uuidString)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        center.add(request) { [weak self] _ in
            Task { @MainActor in
                DebugLogger.log("Notify", "Queued system notification id=\(identifier)")
                self?.scheduleDismissFallback(after: self?.reminderTimeoutSec ?? 60)
            }
        }
    }

    private func registerCategories() {
        guard let center else {
            return
        }

        let rest = UNNotificationAction(
            identifier: restActionIdentifier,
            title: "Rest Now",
            options: [.foreground]
        )
        let snooze5 = UNNotificationAction(
            identifier: snooze5ActionIdentifier,
            title: "Snooze \(AppConfig.shortDurationText(snoozeShortSec))",
            options: []
        )
        let snooze10 = UNNotificationAction(
            identifier: snooze10ActionIdentifier,
            title: "Snooze \(AppConfig.shortDurationText(snoozeMediumSec))",
            options: []
        )
        let snooze20 = UNNotificationAction(
            identifier: snooze20ActionIdentifier,
            title: "Snooze \(AppConfig.shortDurationText(snoozeLongSec))",
            options: []
        )
        let skip = UNNotificationAction(
            identifier: skipActionIdentifier,
            title: "Skip",
            options: []
        )
        let mute = UNNotificationAction(
            identifier: muteTodayActionIdentifier,
            title: "Mute Today",
            options: []
        )

        let category = UNNotificationCategory(
            identifier: categoryIdentifier,
            actions: [rest, snooze5, snooze10, snooze20, skip, mute],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )

        center.setNotificationCategories([category])
    }

    private func scheduleDismissFallback(after seconds: TimeInterval = 60) {
        dismissFallbackWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            DebugLogger.log("Notify", "Notification timeout -> dismiss action")
            self?.onAction?(.dismiss)
        }
        dismissFallbackWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: workItem)
    }

    private func consumeAction(_ action: ReminderAction) {
        dismissFallbackWorkItem?.cancel()
        dismissFallbackWorkItem = nil
        DebugLogger.log("Notify", "Consume action=\(String(describing: action))")
        onAction?(action)
    }
}

extension NotificationController: UNUserNotificationCenterDelegate {
    nonisolated
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        DebugLogger.log("Notify", "willPresent system notification")
        completionHandler([.banner, .sound, .list])
    }

    nonisolated
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let action: ReminderAction
        switch response.actionIdentifier {
        case restActionIdentifier:
            action = .restNow
        case snooze5ActionIdentifier:
            action = .snooze5
        case snooze10ActionIdentifier:
            action = .snooze10
        case snooze20ActionIdentifier:
            action = .snooze20
        case skipActionIdentifier:
            action = .skip
        case muteTodayActionIdentifier:
            action = .muteToday
        case UNNotificationDefaultActionIdentifier, UNNotificationDismissActionIdentifier:
            action = .dismiss
        default:
            action = .dismiss
        }

        completionHandler()

        DebugLogger.log("Notify", "System notification response action=\(String(describing: action))")
        Task { @MainActor [weak self] in
            self?.consumeAction(action)
        }
    }
}
