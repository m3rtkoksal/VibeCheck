import SwiftUI

struct SelfProfileAnalysisView: View {
    @State private var insight: AISelfProfileInsight?
    @State private var errorText: String?
    @State private var isLoading = false
    @State private var didStart = false
    @AppStorage("profile.privateNote") private var privateNote = ""
    @AppStorage("app.hasEnteredMainApp") private var hasEnteredMainApp = false

    var body: some View {
        List {
            Section {
                if isLoading {
                    VStack(spacing: 10) {
                        LottieAnimationPlayer(animationName: "loading")
                            .frame(height: 170)
                            .padding(.top, 4)

                        Text("Profilin için kısa bir özet hazırlanıyor…")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
                }
            }

            if let errorText {
                Section {
                    Text(errorText)
                        .foregroundStyle(.red)
                    Button("Tekrar dene") {
                        Task { await loadInsight(force: true) }
                    }
                }
            }

            if let insight {
                SelfProfileInsightSections(insight: insight)
            }
        }
        .navigationTitle("Profil Analizi")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .safeAreaInset(edge: .bottom) {
            Button {
                hasEnteredMainApp = true
            } label: {
                Text("VibeCheck'e Geç")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.pink)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal)
            .padding(.top, 10)
            .padding(.bottom, 10)
            .background(.ultraThinMaterial)
            .disabled(isLoading && insight == nil && errorText == nil)
            .opacity((isLoading && insight == nil && errorText == nil) ? 0.5 : 1.0)
        }
        .task {
            guard !didStart else { return }
            didStart = true
            await loadInsight(force: false)
        }
    }

    private func loadInsight(force: Bool) async {
        if !force, insight != nil { return }
        errorText = nil
        isLoading = true
        insight = nil
        defer { isLoading = false }

        do {
            let me = ProfileSnapshot.fromLocalDefaults()
            let result = try await AICompatibilityService.analyzeSelfProfile(
                me: me,
                privateNote: privateNote
            )
            insight = result
            SelfProfileInsightStore.save(insight: result)
        } catch {
            errorText = FriendlyCallableError.message(for: error, label: "Profil analizi")
        }
    }
}

#Preview {
    NavigationStack {
        SelfProfileAnalysisView()
    }
}
