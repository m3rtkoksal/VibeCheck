import SwiftUI
import UIKit

// MARK: - Tab / Nav host arka plan (UIKit)

enum MainTabViewChrome {
    static func clearMainWindowBackgroundIfNeeded() {
        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene else { continue }
            for window in windowScene.windows {
                window.backgroundColor = .clear
            }
        }
    }

    static func configureTransparentStacks() {
        let tab = UITabBarAppearance()
        tab.configureWithTransparentBackground()
        tab.backgroundColor = .clear
        let tabBar = UITabBar.appearance()
        tabBar.standardAppearance = tab
        tabBar.scrollEdgeAppearance = tab

        let nav = UINavigationBarAppearance()
        nav.configureWithTransparentBackground()
        nav.backgroundColor = .clear
        let bar = UINavigationBar.appearance()
        bar.standardAppearance = nav
        bar.scrollEdgeAppearance = nav
        bar.compactAppearance = nav
        bar.compactScrollEdgeAppearance = nav
        bar.isTranslucent = true

        UIScrollView.appearance().backgroundColor = .clear
        UITableView.appearance().backgroundColor = .clear
        UICollectionView.appearance().backgroundColor = .clear
    }
}

// MARK: - List / koleksiyon host opak zemini

/// SwiftUI `List` (özellikle iOS 17+) bazı durumlarda `UITableView` / `UICollectionView` kökünde sistem beyazını bırakıyor;
/// `UITableView.appearance()` yetmeyebiliyor — penceredeki örnekleri doğrudan temizler.
struct HostingScrollSurfaceClearTrigger: UIViewRepresentable {
    final class Coordinator {
        weak var attachedWindow: UIWindow?
        var debounceWork: DispatchWorkItem?
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> UIView {
        let v = UIView()
        v.isUserInteractionEnabled = false
        v.backgroundColor = .clear
        return v
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        guard let window = uiView.window else { return }

        context.coordinator.debounceWork?.cancel()
        let work = DispatchWorkItem {
            HostingScrollSurfaceClearTrigger.clearOpaqueScrollSurfaces(from: window)
            context.coordinator.attachedWindow = window
        }
        context.coordinator.debounceWork = work
        DispatchQueue.main.async(execute: work)
    }

    private static func clearOpaqueScrollSurfaces(from root: UIView) {
        var stack: [UIView] = [root]
        var visited = Set<ObjectIdentifier>()
        while let v = stack.popLast() {
            let oid = ObjectIdentifier(v)
            if visited.contains(oid) { continue }
            visited.insert(oid)

            if let tv = v as? UITableView {
                tv.backgroundColor = .clear
                tv.isOpaque = false
            }
            if let cv = v as? UICollectionView {
                cv.backgroundColor = .clear
                cv.isOpaque = false
            }

            stack.append(contentsOf: v.subviews)
        }
    }
}
