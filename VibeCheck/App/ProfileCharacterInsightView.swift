import SwiftUI

/// Profil tabında kayıtlı karakter özetini gösterir; profil değişince yenileme ister.
struct ProfileCharacterInsightView: View {
    @AppStorage("profile.privateNote") private var privateNote = ""
    @State private var payload: SelfProfileInsightStore.Payload?
    @State private var isRefreshing = false
    @State private var errorText: String?

    var body: some View {
        List {
            if SelfProfileInsightStore.isStaleComparedToProfile(),
               payload != nil {
                Section {
                    Text(
                        "Sorularından veya özel notundan biri değişti. "
                            + "Güncel özeti görmek için analizi yenile."
                    )
                    .font(.subheadline)
                    .foregroundStyle(.orange)
                }
            }

            if let errorText {
                Section {
                    Text(errorText)
                        .foregroundStyle(.red)
                }
            }

            if let insight = payload?.insight {
                SelfProfileInsightSections(insight: insight)

                if let savedAt = payload?.savedAt {
                    Section {
                        Text(savedAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } header: {
                        Text("Kaydedilen Özet")
                    }
                }
            } else {
                Section {
                    ContentUnavailableView(
                        "Henüz özet yok",
                        systemImage: "sparkles",
                        description: Text(
                            "Profil analizi tamamlanınca burada saklanır. "
                                + "Aşağıdan şimdi de oluşturabilirsin."
                        )
                    )
                }
            }

            if isRefreshing {
                Section {
                    HStack(spacing: 10) {
                        LottieAnimationPlayer(animationName: "loading")
                            .frame(width: 26, height: 26)
                        Text("Analiz yenileniyor…")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Karakter Özetin")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            Button {
                Task { await refreshInsight() }
            } label: {
                HStack(spacing: 10) {
                    Text(bottomButtonTitle)
                        .font(.headline)
                    if isRefreshing {
                        LottieAnimationPlayer(animationName: "loading")
                            .frame(width: 22, height: 22)
                    }
                }
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
            .disabled(isRefreshing)
            .opacity(isRefreshing ? 0.6 : 1.0)
        }
        .onAppear {
            reloadFromStore()
        }
    }

    private var bottomButtonTitle: String {
        if payload == nil {
            return "Analiz oluştur"
        }
        if SelfProfileInsightStore.isStaleComparedToProfile() {
            return "Analizi yenile"
        }
        return "Analizi yeniden çalıştır"
    }

    private func reloadFromStore() {
        payload = SelfProfileInsightStore.load()
    }

    private func refreshInsight() async {
        errorText = nil
        isRefreshing = true
        defer { isRefreshing = false }

        do {
            let me = ProfileSnapshot.fromLocalDefaults()
            let insight = try await AICompatibilityService.analyzeSelfProfile(
                me: me,
                privateNote: privateNote
            )
            SelfProfileInsightStore.save(insight: insight)
            reloadFromStore()
        } catch {
            errorText = FriendlyCallableError.message(for: error, label: "Profil analizi")
        }
    }
}

#Preview {
    NavigationStack {
        ProfileCharacterInsightView()
    }
}
