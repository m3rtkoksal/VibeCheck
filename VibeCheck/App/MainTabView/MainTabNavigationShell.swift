import SwiftUI

/// Mesh bu `NavigationStack` katmanına bağlanır; `TabView` arkası tek başına görünür olmayabiliyor.
/// Kök görünüm `Color.clear` kalmalı.
struct MainTabNavigationShell<Content: View>: View {
    @ViewBuilder var root: () -> Content

    var body: some View {
        NavigationStack {
            ZStack {
                MeshAuroraBackgroundView()
                    .ignoresSafeArea()
                root()
                    .background(Color.clear)
            }
        }
        .toolbarBackground(Color.clear, for: .navigationBar)
    }
}
