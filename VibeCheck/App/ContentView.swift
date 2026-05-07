import SwiftUI

struct ContentView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("auth.isLoggedIn") private var isLoggedIn = false
    /// İlk kurulum: sorular + karakter analizi bittikten sonra `true` olur; ana tab uygulamasına geçilir.
    @AppStorage("app.hasEnteredMainApp") private var hasEnteredMainApp = false

    var body: some View {
        Group {
            if !hasCompletedOnboarding {
                OnboardingView(hasCompletedOnboarding: $hasCompletedOnboarding)
            } else if !isLoggedIn {
                LoginView(isLoggedIn: $isLoggedIn)
            } else if !hasEnteredMainApp {
                ProfileSetupFlowView()
            } else {
                MainTabView()
            }
        }
    }
}

#Preview {
    ContentView()
}
