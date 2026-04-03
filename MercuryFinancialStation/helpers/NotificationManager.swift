import Foundation
import UserNotifications

actor NotificationManager {
    static let shared = NotificationManager()

    private let center = UNUserNotificationCenter.current()
    private let midnightShiftIdentifier = "midnight_shift_complete"

    func configureMidnightShiftNotification() async {
        let settings = await currentSettings()

        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            await scheduleMidnightShiftNotification()
        case .notDetermined:
            let granted = await requestAuthorization()
            if granted {
                await scheduleMidnightShiftNotification()
            }
        case .denied:
            break
        @unknown default:
            break
        }
    }

    private func scheduleMidnightShiftNotification() async {
        center.removePendingNotificationRequests(withIdentifiers: [midnightShiftIdentifier])

        let content = UNMutableNotificationContent()
        content.title = "Shift Complete"
        content.body = "Your shift is over. Open Mercury Financial Station to review the results."
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: DateComponents(hour: 0, minute: 0),
            repeats: true
        )
        let request = UNNotificationRequest(
            identifier: midnightShiftIdentifier,
            content: content,
            trigger: trigger
        )

        await withCheckedContinuation { continuation in
            center.add(request) { _ in
                continuation.resume()
            }
        }
    }

    private func currentSettings() async -> UNNotificationSettings {
        await withCheckedContinuation { continuation in
            center.getNotificationSettings { settings in
                continuation.resume(returning: settings)
            }
        }
    }

    private func requestAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                continuation.resume(returning: granted)
            }
        }
    }
}
