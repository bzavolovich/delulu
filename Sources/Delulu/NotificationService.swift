import AppKit
import DeluluCore
import UserNotifications

@MainActor final class NotificationService: NSObject, NotificationScheduling, UNUserNotificationCenterDelegate {
    private let center: UNUserNotificationCenter?
    var onOpen: (() -> Void)?

    override init() {
        // UNUserNotificationCenter raises an Objective-C exception in an unbundled executable.
        let bundle = Bundle.main
        if bundle.bundleURL.pathExtension == "app", bundle.bundleIdentifier != nil,
           bundle.infoDictionary?["CFBundlePackageType"] as? String == "APPL" {
            center = UNUserNotificationCenter.current()
        } else { center = nil }
        super.init()
        center?.delegate = self
    }

    func permission() async -> NotificationPermission {
        guard let center else { return .unavailable }
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral: return .allowed
        case .denied: return .denied
        case .notDetermined: return .notRequested
        @unknown default: return .denied
        }
    }

    func requestPermission() async throws -> Bool {
        guard let center else { return false }
        return try await center.requestAuthorization(options: [.alert, .sound])
    }

    func schedule(_ schedule: RecurringSchedule) async throws {
        guard let center else { throw CocoaError(.featureUnsupported) }
        let content = content(for: schedule.message, sound: schedule.soundEnabled)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: schedule.cadence.interval, repeats: true)
        try await center.add(UNNotificationRequest(identifier: RecurringSchedule.notificationID, content: content, trigger: trigger))
    }

    func sendNow(_ message: RecruiterMessage, sound: Bool) async throws {
        guard let center else { throw CocoaError(.featureUnsupported) }
        // A nil trigger delivers immediately; a separate identifier leaves the repeating request alone.
        try await center.add(UNNotificationRequest(identifier: "delulu.instant.\(UUID().uuidString)",
                                                   content: content(for: message, sound: sound), trigger: nil))
    }

    private func content(for message: RecruiterMessage, sound: Bool) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = message.notificationTitle
        content.subtitle = message.notificationSubtitle
        content.body = message.body
        content.sound = sound ? .default : nil
        content.threadIdentifier = "delulu.\(message.mode.rawValue)"
        return content
    }

    func cancelRecurring() {
        center?.removePendingNotificationRequests(withIdentifiers: [RecurringSchedule.notificationID])
    }

    func preparePendingRequests() async throws {
        guard let center else { return }
        let requests = await center.pendingNotificationRequests()
        let identifiers = requests.map(\.identifier)
            .filter { $0.hasPrefix("delulu.") && $0 != RecurringSchedule.notificationID }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)

        // Pending requests retain their original text across app updates.
        // Replace only the old subtitle once, without creating another repeating request.
        let oldPrefix = "Delulu fiction · "
        for request in requests where request.identifier == RecurringSchedule.notificationID {
            guard request.content.subtitle.hasPrefix(oldPrefix),
                  let content = request.content.mutableCopy() as? UNMutableNotificationContent else { continue }
            content.subtitle = String(content.subtitle.dropFirst(oldPrefix.count))
            try await center.add(UNNotificationRequest(identifier: request.identifier, content: content, trigger: request.trigger))
        }
    }

    func hasRecurringRequest() async -> Bool {
        guard let center else { return false }
        return await center.pendingNotificationRequests().contains { $0.identifier == RecurringSchedule.notificationID }
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                           willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        return [.banner, .list, .sound]
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                           didReceive response: UNNotificationResponse) async {
        guard response.actionIdentifier == UNNotificationDefaultActionIdentifier else { return }
        await MainActor.run { onOpen?() }
    }
}
