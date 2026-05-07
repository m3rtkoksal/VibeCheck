import SwiftUI

/// İlk kurulum: sorular → özet → kişisel karakter analizi → ana tab uygulaması.
struct ProfileSetupFlowView: View {
    @State private var showSummary = false

    var body: some View {
        NavigationStack {
            ProfileEditorView(setupMode: true, showSummary: $showSummary)
                .navigationDestination(isPresented: $showSummary) {
                    ProfileSummaryView(selections: ProfileEditorView.selectionsDictionary())
                }
        }
    }
}

#Preview {
    ProfileSetupFlowView()
}
