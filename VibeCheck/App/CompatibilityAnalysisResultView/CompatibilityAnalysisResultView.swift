import SwiftUI

struct CompatibilityAnalysisResultView: View {
    @StateObject private var vm: CompatibilityAnalysisResultViewModel
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @AppStorage("profile.photoSaved") private var photoSaved = false

    init(output: AIOnlyAnalysisOutput) {
        _vm = StateObject(wrappedValue: CompatibilityAnalysisResultViewModel(output: output))
    }

    var body: some View {
        resultMainStack
            .safeAreaInset(edge: .bottom) {
                saveRatingBottomInset
            }
            .alert("Değerlendirme kaydedildi", isPresented: $vm.showSavedAlert) {
                Button("Tamam", role: .cancel) {}
            } message: {
                Text("Puanın kaydedildi. Geçmiş ekranında uyum puanının yanında görebilirsin.")
            }
            .onAppear {
                vm.loadAvatar(photoSaved: photoSaved)
                vm.refreshReceivedRating()
                IncomingCompatibilityRatingsNotifier.shared.markIncomingDetailOpened(docId: vm.output.incomingFirestoreDocId)
            }
            .onChange(of: photoSaved) { _, _ in
                vm.loadAvatar(photoSaved: photoSaved)
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(Color.primary)
                            .frame(width: 36, height: 36)
                            .background(
                                HarmonyPanelChrome.toolbarBackGlass(
                                    diameter: 36,
                                    colorScheme: colorScheme,
                                    reduceTransparency: reduceTransparency
                                )
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Geri")
                }
                ToolbarItem(placement: .principal) {
                    CompatibilityResultToolbarTitle()
                }
            }
            .toolbarBackground(Color.clear, for: .navigationBar)
    }

    private var resultMainStack: some View {
        ZStack {
            MeshAuroraBackgroundView()
                .ignoresSafeArea()

            VStack(spacing: 10) {
                ResultTopTabStrip(selectedTab: $vm.selectedTab)

                TabView(selection: $vm.selectedTab) {
                    UyumResultTabContent(vm: vm)
                        .tag(ResultTopTab.uyum)
                    BuzkiranResultTabContent(vm: vm)
                        .tag(ResultTopTab.buzkiran)
                    OngoruResultTabContent(vm: vm)
                        .tag(ResultTopTab.ongoru)
                    DegerlendirmeResultTabContent(vm: vm)
                        .tag(ResultTopTab.degerlendirme)
                    PuanimResultTabContent(vm: vm)
                        .tag(ResultTopTab.puanim)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .background(Color.clear)
            }
            .background(Color.clear)
        }
    }

    @ViewBuilder
    private var saveRatingBottomInset: some View {
        if vm.selectedTab == .degerlendirme, vm.canSaveRating {
            Button {
                vm.saveRating()
            } label: {
                Text("Puanı Kaydet")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(HarmonyPanelChrome.primaryCTAFill(cornerRadius: 14, colorScheme: colorScheme))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 10)
            .background(.ultraThinMaterial)
        }
    }
}

#Preview {
    NavigationStack {
        CompatibilityAnalysisResultView(
            output: AIOnlyAnalysisOutput(
                partnerQuery: "@ornek",
                ai: AICompatibilityInsight(
                    percent: 85,
                    strengths: ["Both prioritize empathy and personal growth.", "Excellent flow; open and non-judgmental interactions."],
                    frictions: ["Karar alma hızı farklı"],
                    summary: "Your personalities are highly complementary."
                )
            )
        )
    }
}
