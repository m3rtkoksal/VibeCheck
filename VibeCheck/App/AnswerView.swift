import SwiftUI

struct AnswerView: View {
    let category: ProfileCategory
    let onContinue: (ProfileCategory) -> Bool

    @AppStorage private var selection: String
    @State private var draftSelection: String = ""
    @StateObject private var discoverabilityVM = SettingsDetailViewModel()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    init(category: ProfileCategory, onContinue: @escaping (ProfileCategory) -> Bool) {
        self.category = category
        self.onContinue = onContinue
        _selection = AppStorage(wrappedValue: "", "profile.category.\(category.id)")
    }

    var body: some View {
        ZStack {
            MeshAuroraBackgroundView()
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    progressHeader

                    categoryBadgeRow

                    Text(questionTitle)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.primary)

                    Text(questionSubtitle)
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 2)

                    VStack(spacing: 10) {
                        ForEach(Array(category.options.enumerated()), id: \.offset) { idx, option in
                            optionRow(index: idx + 1, option: option)
                        }
                    }

                    if !draftSelection.isEmpty {
                        clearSelectionButton
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 110)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color.clear)
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbarBackground(Color.clear, for: .navigationBar)
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
                answerToolbarTitle
            }
        }
        .safeAreaInset(edge: .bottom) {
            bottomActionBar
        }
        .onAppear {
            draftSelection = selection
        }
    }

    private var answerToolbarTitle: some View {
        let dark = colorScheme == .dark
        return Text("VibeCheck")
            .font(.system(size: 20, weight: .heavy, design: .default))
            .tracking(-0.6)
            .foregroundStyle(.primary)
            .shadow(color: dark ? Color.black.opacity(0.55) : Color.black.opacity(0.22), radius: 0, x: 0, y: 1)
            .shadow(color: dark ? Color.black.opacity(0.35) : Color.black.opacity(0.08), radius: 2, x: 0, y: 0)
            .shadow(color: dark ? Color.white.opacity(0.12) : Color.clear, radius: 1, x: 0, y: -0.5)
    }

    private var categoryBadgeRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color(hex: 0x3B82F6))
            Text("İlişki Dinamikleri")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color(hex: 0x3B82F6))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(HarmonyPanelChrome.insetWell(cornerRadius: 12, colorScheme: colorScheme))
    }

    private var bottomActionBar: some View {
        HStack(spacing: 10) {
            Button {
                saveAndPause()
            } label: {
                Image(systemName: "pause.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 54, height: 54)
                    .foregroundStyle(.white)
                    .background(answerPauseChrome)
            }
            .buttonStyle(.plain)

            Button {
                saveAndContinue()
            } label: {
                HStack(spacing: 8) {
                    Text("Devam Et")
                        .font(.headline)
                    Image(systemName: "arrow.forward")
                        .font(.system(size: 14, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .foregroundStyle(.white)
                .background(HarmonyPanelChrome.primaryCTAFill(cornerRadius: 14, colorScheme: colorScheme))
            }
            .buttonStyle(.plain)
            .disabled(draftSelection.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .opacity(draftSelection.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.6 : 1.0)
        }
        .padding(.horizontal)
        .padding(.top, 10)
        .padding(.bottom, 10)
        .background(.ultraThinMaterial)
    }

    /// Duraklat — opak siyah yerine cam + yoğun koyu dolgu (detay geri ile uyumlu dil).
    private var answerPauseChrome: some View {
        let corner: CGFloat = 14
        let shape = RoundedRectangle(cornerRadius: corner, style: .continuous)
        return ZStack {
            shape.fill(Material.thin)
            shape.fill(Color.black.opacity(colorScheme == .dark ? 0.52 : 0.78))
        }
        .clipShape(shape)
        .overlay {
            shape.strokeBorder(Color.white.opacity(colorScheme == .dark ? 0.14 : 0.22), lineWidth: 1)
        }
    }

    private var clearSelectionButton: some View {
        Button {
            draftSelection = ""
        } label: {
            Text("Seçimi temizle")
                .font(.system(size: 15, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .foregroundStyle(Color(hex: 0xB45309))
                .background(
                    HarmonyPanelChrome.secondaryTintedButtonBackground(
                        cornerRadius: 14,
                        colorScheme: colorScheme,
                        tint: Color(hex: 0xB45309)
                    )
                )
        }
        .buttonStyle(.plain)
    }

    private var progressHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Soru \(questionNumber) / \(totalQuestions)")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.primary.opacity(colorScheme == .dark ? 0.12 : 0.08))
                    Capsule()
                        .fill(Color(hex: 0x3B82F6))
                        .frame(width: geo.size.width * progress)
                }
            }
            .frame(height: 8)
            .padding(.horizontal, 2)
        }
        .padding(14)
        .background(
            HarmonyPanelChrome.panelBackdrop(cornerRadius: 16, colorScheme: colorScheme)
                .shadow(color: HarmonyPanelChrome.cardShadow(colorScheme: colorScheme), radius: 10, x: 0, y: 4)
        )
    }

    private func optionRow(index: Int, option: String) -> some View {
        let selected = (draftSelection == option)
        return Button {
            draftSelection = option
        } label: {
            HStack(spacing: 12) {
                Text("\(index)")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(selected ? Color(hex: 0x3B82F6) : Color.secondary)
                    .frame(width: 24)

                Text(option)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)

                Spacer(minLength: 8)

                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(selected ? Color(hex: 0x3B82F6) : Color(.tertiaryLabel))
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                HarmonyPanelChrome.panelBackdrop(cornerRadius: 16, colorScheme: colorScheme)
                    .shadow(color: HarmonyPanelChrome.cardShadow(colorScheme: colorScheme), radius: 10, x: 0, y: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        selected ? Color(hex: 0x3B82F6).opacity(0.52) : Color.primary.opacity(colorScheme == .dark ? 0.12 : 0.07),
                        lineWidth: selected ? 1.5 : 1
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private var totalQuestions: Int {
        ProfileCategory.allCases.count + 1
    }

    private var questionNumber: Int {
        let idx = ProfileCategory.allCases.firstIndex(of: category) ?? 0
        return idx + 1
    }

    private var progress: CGFloat {
        guard totalQuestions > 0 else { return 0 }
        return CGFloat(questionNumber) / CGFloat(totalQuestions)
    }

    private var questionTitle: String {
        switch category {
        case .messageTempo:
            return "Mesajlara geç cevap gelince ne hissedersin?"
        case .repairAfterConflict:
            return "Küçük bir tartışmadan sonra ne yaparsın?"
        case .boundaryStyle:
            return "Bir şeye kırıldığında nasıl davranırsın?"
        case .closenessNeed:
            return "Yeni tanıştığın biriyle yakınlaşma hızın nasıldır?"
        case .jealousyTrigger:
            return "Partnerin karşı cins biriyle sık görüşürse ne hissedersin?"
        }
    }

    private var questionSubtitle: String {
        switch category {
        case .messageTempo:
            return "Sana en doğal gelen tepkiyi seç."
        case .repairAfterConflict:
            return "Sorunu çözme tarzını en iyi anlatan seçeneği işaretle."
        case .boundaryStyle:
            return "Duygunu ifade etme şekline en yakın seçeneği seç."
        case .closenessNeed:
            return "İlişkide yakınlık kurma hızını düşünerek cevapla."
        case .jealousyTrigger:
            return "Bu durumda içten içe en çok hangi tepki oluşur?"
        }
    }

    private func saveAndPause() {
        selection = draftSelection
        triggerDiscoverabilitySync()
        dismiss()
    }

    private func saveAndContinue() {
        selection = draftSelection
        triggerDiscoverabilitySync()
        let moved = onContinue(category)
        if !moved {
            dismiss()
        }
    }

    private func triggerDiscoverabilitySync() {
        Task {
            discoverabilityVM.syncFromFirebaseUser()
            await discoverabilityVM.syncDiscoverabilityIndex()
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

