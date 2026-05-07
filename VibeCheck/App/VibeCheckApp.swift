import SwiftUI
import FirebaseCore
import FirebaseAuth

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        FirebaseApp.configure()

        // SMS OTP: sessiz APNs ile doğrulama (gerçek cihaz). Simulator’da token olmayabilir;
        // Firebase o durumda reCAPTCHA / güvenlik akışına düşer.
        application.registerForRemoteNotifications()

        #if DEBUG && targetEnvironment(simulator)
        // Keep bypass only on Simulator.
        // On real devices, Firebase phone auth should use normal app verification.
        Auth.auth().settings?.isAppVerificationDisabledForTesting = true
        #endif

        // MVP: ensure there is always a Firebase Auth user so callable functions can enforce auth.
        Task {
            if Auth.auth().currentUser == nil {
                _ = try? await Auth.auth().signInAnonymously()
            }
        }

        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        #if DEBUG
        Auth.auth().setAPNSToken(deviceToken, type: .sandbox)
        #else
        Auth.auth().setAPNSToken(deviceToken, type: .prod)
        #endif
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        // Simulator veya yetkisiz profil: Firebase Phone Auth yine de reCAPTCHA ile devam edebilir.
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
        // Firebase Auth (Phone/Twitter) callback URL'lerini yakala.
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
