import SwiftUI

struct AnswerView: View {
    let category: ProfileCategory
    let onContinue: (ProfileCategory) -> Bool

    @AppStorage private var selection: String
    @State private var draftSelection: String = ""
    @StateObject private var discoverabilityVM = SettingsDetailViewModel()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    init(category: ProfileCategory, onContinue: @escaping (ProfileCategory) -> Bool) {
        self.category = category
        self.onContinue = onContinue
        _selection = AppStorage(wrappedValue: "", "profile.category.\(category.id)")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                progressHeader

                HStack(spacing: 8) {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color(hex: 0xFF2D55))
                    Text("İlişki Dinamikleri")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color(hex: 0xFF2D55))
                }

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
                    Button(role: .destructive) {
                        draftSelection = ""
                    } label: {
                        Text("Seçimi temizle")
                            .font(.system(size: 15, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.red.opacity(0.08))
                            .foregroundStyle(.red)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 110)
        }
        .background(
            LinearGradient(
                colors: [
                    colorScheme == .dark ? Color(hex: 0x12131A) : Color(hex: 0xFFF6F7),
                    colorScheme == .dark ? Color(hex: 0x171A24) : Color(hex: 0xF3F6FF),
                    colorScheme == .dark ? Color(hex: 0x0D0E14) : Color.white,
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        )
        .navigationTitle("VibeCheck")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 10) {
                Button {
                    saveAndPause()
                } label: {
                    Image(systemName: "pause.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(width: 54, height: 54)
                        .background(Color.black)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }

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
                    .background(Color.pink)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .disabled(draftSelection.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .opacity(draftSelection.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.6 : 1.0)
            }
            .padding(.horizontal)
            .padding(.top, 10)
            .padding(.bottom, 10)
            .background(.ultraThinMaterial)
        }
        .onAppear {
            draftSelection = selection
        }
    }

    private var progressHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Soru \(questionNumber) / \(totalQuestions)")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.secondary.opacity(0.15))
                    Capsule()
                        .fill(Color(hex: 0xFF2D55))
                        .frame(width: geo.size.width * progress)
                }
            }
            .frame(height: 8)
        }
    }

    private func optionRow(index: Int, option: String) -> some View {
        let selected = (draftSelection == option)
        return Button {
            draftSelection = option
        } label: {
            HStack(spacing: 12) {
                Text("\(index)")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(selected ? Color(hex: 0xFF2D55) : Color.secondary)
                    .frame(width: 24)

                Text(option)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)

                Spacer(minLength: 8)

                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(selected ? Color(hex: 0xFF2D55) : Color(.tertiaryLabel))
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(.systemBackground))
                    .shadow(color: Color.black.opacity(0.03), radius: 10, x: 0, y: 5)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        selected ? Color(hex: 0xFF2D55).opacity(0.45) : Color(.separator).opacity(0.25),
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

