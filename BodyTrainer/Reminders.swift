import Foundation
import UserNotifications

/// The weigh-in prompt is a notification with an inline text field
/// (UNTextInputNotificationAction) — pull it down, type the number, Send. No app launch.
enum Reminders {
    static let category = "WEIGH_IN"
    static let logAction = "LOG_WEIGHT"
    private static let idPrefix = "weighin-"

    static func registerCategory() {
        let reply = UNTextInputNotificationAction(
            identifier: logAction,
            title: "Log weight",
            // Health refuses writes while the phone is locked, so unlock first.
            options: [.authenticationRequired],
            textInputButtonTitle: "Log",
            textInputPlaceholder: "e.g. 196.4")
        let cat = UNNotificationCategory(identifier: category, actions: [reply],
                                         intentIdentifiers: [], options: [])
        UNUserNotificationCenter.current().setNotificationCategories([cat])
    }

    static func requestPermission() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    private static func content() -> UNMutableNotificationContent {
        let c = UNMutableNotificationContent()
        c.title = "Weigh-in"
        c.body = "What's the weigh-in today? Hold or pull down to log it."
        c.sound = .default
        c.categoryIdentifier = category
        c.interruptionLevel = .timeSensitive
        return c
    }

    /// weekdays use Calendar numbering: 1 = Sunday … 7 = Saturday.
    static func schedule(weekdays: Set<Int>, hour: Int, minute: Int) async {
        let center = UNUserNotificationCenter.current()
        let old = await center.pendingNotificationRequests().map(\.identifier).filter { $0.hasPrefix(idPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: old)

        for day in weekdays {
            var comps = DateComponents()
            comps.weekday = day
            comps.hour = hour
            comps.minute = minute
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
            try? await center.add(UNNotificationRequest(identifier: "\(idPrefix)\(day)", content: content(), trigger: trigger))
        }
    }

    static func sendTest(after seconds: TimeInterval = 5) async {
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false)
        try? await UNUserNotificationCenter.current()
            .add(UNNotificationRequest(identifier: "test-\(UUID())", content: content(), trigger: trigger))
    }

    static func confirm(_ text: String) async {
        let c = UNMutableNotificationContent()
        c.title = "Weigh-in"
        c.body = text
        try? await UNUserNotificationCenter.current()
            .add(UNNotificationRequest(identifier: "logged-\(UUID())", content: c, trigger: nil))
    }

    /// "196.4", "196,4", "196.4 lb" → 196.4
    static func parse(_ raw: String) -> Double? {
        let cleaned = raw.replacingOccurrences(of: ",", with: ".")
            .filter { $0.isNumber || $0 == "." }
        guard let v = Double(cleaned), v > 20, v < 1000 else { return nil }
        return v
    }
}
