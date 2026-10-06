import SwiftUI
import UserNotifications

@main
struct BodyTrainerApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(WeightLog.shared.container)
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // Must be set before launch finishes or a background reply is dropped.
        UNUserNotificationCenter.current().delegate = self
        Reminders.registerCategory()
        return true
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse) async {
        guard response.actionIdentifier == Reminders.logAction,
              let reply = response as? UNTextInputNotificationResponse else { return }
        guard let value = Reminders.parse(reply.userText) else {
            await Reminders.confirm("Couldn't read \"\(reply.userText)\" — open BodyTrainer to log it.")
            return
        }
        let result = await WeightLog.shared.log(value)
        await Reminders.confirm(result.summary)
    }
}
