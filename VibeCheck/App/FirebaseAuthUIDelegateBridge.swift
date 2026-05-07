import UIKit
import FirebaseAuth

/// Firebase Phone / OAuth tarayıcı veya reCAPTCHA için sunum delegesi.
final class FirebaseAuthUIDelegateBridge: NSObject, AuthUIDelegate {
    func present(
        _ viewControllerToPresent: UIViewController,
        animated flag: Bool,
        completion: (() -> Void)?
    ) {
        guard let host = UIApplication.shared.vc_topMostViewController() else {
            completion?()
            return
        }
        host.present(viewControllerToPresent, animated: flag, completion: completion)
    }

    func dismiss(animated flag: Bool, completion: (() -> Void)?) {
        UIApplication.shared.vc_topMostViewController()?.dismiss(animated: flag, completion: completion)
    }
}
