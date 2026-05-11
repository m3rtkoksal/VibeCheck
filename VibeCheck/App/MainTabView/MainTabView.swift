import SwiftUI

/// Giriş tamamlandıktan ve ilk kurulum pipeline’ı bittikten sonra görünen ana kabuk (tab’lar).
struct MainTabView: View {
    @State private var selectedTab: MainTab = .history

    init() {
        MainTabViewChrome.configureTransparentStacks()
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            MainTabNavigationShell {
                ProfileEditorView()
            }
            .tag(MainTab.profile)
            .tabItem {
                Label("Profil", systemImage: "person.circle.fill")
            }

            MainTabNavigationShell {
                CompatibilityAnalysisView()
            }
            .tag(MainTab.compatibility)
            .tabItem {
                Label("Uyum", systemImage: "heart.text.square.fill")
            }

            MainTabNavigationShell {
                CompatibilityHistoryView()
            }
            .tag(MainTab.history)
            .tabItem {
                Label("Geçmiş", systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90")
            }

            MainTabNavigationShell {
                SettingsTabView()
            }
            .tag(MainTab.settings)
            .tabItem {
                Label("Ayarlar", systemImage: "gearshape.fill")
            }
        }
        .background {
            HostingScrollSurfaceClearTrigger()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .allowsHitTesting(false)
        }
        .background(Color.clear)
        .toolbarBackground(Color.clear, for: .tabBar)
        .tint(Color(mtHex: 0x2563EB))
        .onReceive(NotificationCenter.default.publisher(for: .vibecheckOpenHistoryTab)) { _ in
            selectedTab = .history
        }
        .onAppear {
            MainTabViewChrome.clearMainWindowBackgroundIfNeeded()
        }
    }
}

#Preview {
    MainTabView()
}
