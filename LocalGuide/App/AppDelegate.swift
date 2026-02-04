import UIKit
import UserNotifications
import FirebaseCore
import FirebaseMessaging
#if canImport(GoogleSignIn)
import GoogleSignIn
#endif

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate, MessagingDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // FirebaseApp is already configured in LocalGuideApp.init()
        UNUserNotificationCenter.current().delegate = self
        requestNotificationAuthorization()
        application.registerForRemoteNotifications()

        Messaging.messaging().delegate = self
        return true
    }

    private func requestNotificationAuthorization() {
        if AppEnvironment.isUITest { return }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if let error = error {
                print("Notification authorization error: \(error)")
            }
        }
    }

    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        // Provide APNs token to Firebase Messaging
        Messaging.messaging().apnsToken = deviceToken
    }

    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("Failed to register for remote notifications: \(error)")
    }

    // Observe FCM token updates
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        print("FCM token: \(fcmToken ?? "nil")")
        // TODO: Optionally send this token to your backend server.
    }

#if canImport(GoogleSignIn)
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        return GIDSignIn.sharedInstance.handle(url)
    }
#else
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        // GoogleSignIn SDK not available; no URL handling needed
        return false
    }
#endif
}
