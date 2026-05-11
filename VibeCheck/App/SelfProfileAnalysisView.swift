import SwiftUI

struct SelfProfileAnalysisView: View {
    @State private var insight: AISelfProfileInsight?
    @State private var errorText: String?
    @State private var isLoading = false
    @State private var didStart = false
    @AppStorage("profile.privateNote") private var privateNote = ""
    @AppStorage("app.hasEnteredMainApp") private var hasEnteredMainApp = false

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            MeshAuroraBackgroundView()
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if isLoading {
                        VStack(spacing: 12) {
                            LottieAnimationPlayer(animationName: "loading")
                                .frame(height: 140)
                                .padding(.top, 8)

                            Text("Profilin için kısa bir özet hazırlanıyor…")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity)
                        }
                        .padding(.vertical, 16)
                    }

                    if let errorText {
                        Text(errorText)
                            .font(.system(size: 15))
                            .foregroundStyle(Color(hex: 0xB45309))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16)
                            .background(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(Color(hex: 0xDBEAFE).opacity(0.45))
                            )

                        Button("Tekrar dene") {
                            Task { await loadInsight(force: true) }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color(hex: 0x3B82F6))
                        .frame(maxWidth: .infinity)
                    }

                    if let insight {
                        SelfProfileInsightSections(insight: insight, bottomSpacerMin: 24)
                    }
                }
                .frame(maxWidth: 680)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 120)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color.clear)
        }
        .navigationTitle("Profil Analizi")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbarBackground(Color.clear, for: .navigationBar)
        .tint(Color(hex: 0x2563EB))
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Button {
                hasEnteredMainApp = true
            } label: {
                Text("VibeCheck'e Geç")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.white)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 56)
                    .background(Color(hex: 0x3B82F6))
                    .clipShape(Capsule(style: .continuous))
                    .shadow(color: Color(hex: 0x3B82F6).opacity(0.2), radius: 16, x: 0, y: 8)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 14)
            .frame(maxWidth: .infinity)
            .background(.regularMaterial.opacity(colorScheme == .dark ? 0.9 : 0.92))
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

private extension Color {
    init(hex: UInt32, alpha: Double = 1.0) {
        let r = Double((hex & 0xFF0000) >> 16) / 255.0
        let g = Double((hex & 0x00FF00) >> 8) / 255.0
        let b = Double(hex & 0x0000FF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }
}

#Preview {
    NavigationStack {
        SelfProfileAnalysisView()
    }
}
