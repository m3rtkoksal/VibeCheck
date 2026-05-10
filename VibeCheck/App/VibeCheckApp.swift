import SwiftUI
import FirebaseCore
import FirebaseAuth
import FirebaseMessaging
import UserNotifications

final class AppDelegate: NSObject, UIApplicationDelegate, MessagingDelegate,
    UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        FirebaseApp.configure()

        Messaging.messaging().delegate = self
        UNUserNotificationCenter.current().delegate = self

        // SMS OTP: sessiz APNs ile doğrulama (gerçek cihaz). Simulator’da token olmayabilir;
        // Firebase o durumda reCAPTCHA / güvenlik akışına düşer.
        application.registerForRemoteNotifications()

        #if DEBUG && targetEnvironment(simulator)
        // Keep bypass only on Simulator.
        // On real devices, Firebase phone auth should use normal app verification.
        Auth.auth().settings?.isAppVerificationDisabledForTesting = true
        #endif

        // FCM token çoğu zaman girişten önce gelir; oturum açılınca yeniden kaydedilsin.
        Auth.auth().addStateDidChangeListener { _, user in
            if user != nil {
                UserPushTokenSync.refreshMessagingRegistration()
            }
        }

        return true
    }

    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let fcmToken else { return }
        Task {
            await UserPushTokenSync.persist(token: fcmToken)
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        if let type = userInfo["type"] as? String, type == "compatibility_rating" {
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .vibecheckOpenHistoryTab, object: nil)
            }
        }
        completionHandler()
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Messaging.messaging().apnsToken = deviceToken
        #if DEBUG
        Auth.auth().setAPNSToken(deviceToken, type: .sandbox)
        #else
        Auth.auth().setAPNSToken(deviceToken, type: .prod)
        #endif
        UserPushTokenSync.refreshMessagingRegistration()
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        NSLog("APNs kaydı yok: %@", error.localizedDescription)
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        if Auth.auth().canHandleNotification(userInfo) {
            completionHandler(.noData)
            return
        }
        completionHandler(.noData)
    }

    func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        if Auth.auth().canHandle(url) {
            return true
        }
        return false
    }
}

@main
struct VibeCheckApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    /// 0: sistem, 1: açık, 2: koyu
    @AppStorage("app.colorSchemePreference") private var colorSchemePreference = 0

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(resolvedColorScheme)
                .onOpenURL { url in
                    _ = Auth.auth().canHandle(url)
                }
        }
    }

    private var resolvedColorScheme: ColorScheme? {
        switch colorSchemePreference {
        case 1: return .light
        case 2: return .dark
        default: return nil
        }
    }
}
