import UIKit

extension UIApplication {
    /// Önde görünen VC (OAuth / SMS arayüzleri için).
    func vc_topMostViewController(from root: UIViewController? = nil) -> UIViewController? {
        let root = root ?? connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }?
            .rootViewController

        guard let root else { return nil }

        if let presented = root.presentedViewController {
            return vc_topMostViewController(from: presented)
        }
        if let nav = root as? UINavigationController {
            return vc_topMostViewController(from: nav.visibleViewController)
        }
        if let tab = root as? UITabBarController {
            return vc_topMostViewController(from: tab.selectedViewController)
        }
        return root
    }
}
