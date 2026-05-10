import SwiftUI
import UIKit

struct CompatibilityAnalysisResultView: View {
    @StateObject private var vm: CompatibilityAnalysisResultViewModel
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("profile.photoSaved") private var photoSaved = false

    init(output: AIOnlyAnalysisOutput) {
        _vm = StateObject(wrappedValue: CompatibilityAnalysisResultViewModel(output: output))
    }

    var body: some View {
        VStack(spacing: 10) {
            topTabs

            TabView(selection: $vm.selectedTab) {
                uyumPage.tag(ResultTopTab.uyum)
                buzkiranPage.tag(ResultTopTab.buzkiran)
                ongoruPage.tag(ResultTopTab.ongoru)
                degerlendirmePage.tag(ResultTopTab.degerlendirme)
                puanimPage.tag(ResultTopTab.puanim)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
        .safeAreaInset(edge: .bottom) {
            if vm.selectedTab == .degerlendirme, vm.canSaveRating {
                Button {
                    vm.saveRating()
                } label: {
                    Text("Puanı Kaydet")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.pink)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 10)
                .background(.ultraThinMaterial)
            }
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
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("VibeCheck")
                    .font(.system(size: 20, weight: .black, design: .default))
                    .tracking(-0.6)
                    .foregroundStyle(Color(hex: 0xFF2D55))
            }
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
    }

    private var topTabs: some View {
        HStack(spacing: 0) {
            ForEach(ResultTopTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        vm.selectedTab = tab
                    }
                } label: {
                    Text(tab.title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(
                            vm.selectedTab == tab ?
                                Color(hex: 0xE51245) :
                                Color(.secondaryLabel)
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(
                                    vm.selectedTab == tab ?
                                        Color(hex: 0xFFE8EE) :
                                        Color.clear
                                )
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 999, style: .continuous)
                .fill(Color(.systemBackground).opacity(0.86))
                .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 4)
                .overlay(
                    RoundedRectangle(cornerRadius: 999, style: .continuous)
                        .stroke(Color.white.opacity(0.65), lineWidth: 1)
                )
        )
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private var uyumPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Uyum Sonucu")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(.primary)
                    .padding(.top, 6)

                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("\(vm.output.ai.percent)%")
                            .font(.system(size: 40, weight: .black))
                            .foregroundStyle(Color(hex: 0xFF2D55))
                        Text("Uyum")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.primary)
                    }

                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .foregroundStyle(Color(hex: 0xFF2D55))
                        Text("AI Özeti")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.primary)
                    }

                    Text(vm.output.ai.summary)
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color(.systemBackground))
                        .shadow(color: Color.black.opacity(0.04), radius: 14, x: 0, y: 8)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color(.separator).opacity(0.25), lineWidth: 1)
                )

                Text("Neden Uyumlusunuz?")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.primary)
                    .padding(.top, 4)

                VStack(spacing: 10) {
                    ForEach(Array(vm.reasonItems.enumerated()), id: \.offset) { idx, item in
                        reasonCard(
                            title: item.title,
                            text: item.text,
                            icon: idx == 0 ? "heart.fill" : "bubble.left.and.bubble.right.fill",
                            tint: idx == 0 ? Color(hex: 0xFF2D55) : Color(hex: 0x2563EB)
                        )
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 110)
        }
    }

    private var buzkiranPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Sohbet Başlatıcılar")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.primary)
                    .padding(.top, 6)

                Text("Yapay zeka analizine göre sohbeti başlatmak için en iyi cümleler.")
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)

                VStack(spacing: 12) {
                    ForEach(Array(buzkiranPromptCards.enumerated()), id: \.offset) { idx, card in
                        buzkiranCard(index: idx, item: card)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 110)
        }
    }

    private var ongoruPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                forecastProfilesRow
                    .padding(.top, 6)

                VStack(spacing: 10) {
                    ForEach(Array(ongoruForecastCards.enumerated()), id: \.offset) { _, item in
                        ongoruCard(item: item)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 110)
        }
    }

    private var degerlendirmePage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Randevu Değerlendirmesi")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(.primary)
                    .padding(.top, 6)

                Text("Bu bilgiler tamamen gizlidir ve sadece AI analizi için kullanılır.")
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)

                sliderCard(
                    title: "Egosu ortamı bastırdı mı?",
                    value: $vm.egoScore,
                    minLabel: "MÜTEVAZI",
                    maxLabel: "TEK KİŞİLİK SAHNE"
                )

                sliderCard(
                    title: "Samimiyet hissi nasıldı?",
                    value: $vm.sincerityScore,
                    minLabel: "TAMAMEN ROL",
                    maxLabel: "DOĞAL VE GERÇEK"
                )

                sliderCard(
                    title: "Niyeti neydi?",
                    value: $vm.intentScore,
                    minLabel: "SADECE ETKİLEME",
                    maxLabel: "SENİ TANIMAYA ODAKLI"
                )

                sliderCard(
                    title: "Sohbet akışı nasıldı?",
                    value: $vm.flowScore,
                    minLabel: "ZORLADI / AKMADI",
                    maxLabel: "DOĞAL / KEYİFLİ"
                )

                sliderCard(
                    title: "Cinsel odak seviyesi nasıldı?",
                    value: $vm.sexualFocusScore,
                    minLabel: "HİÇ YOK",
                    maxLabel: "AŞIRI BASKIN"
                )

                binaryCard(
                    title: "Para / statü gösterme ihtiyacı hissettirdi mi?",
                    value: $vm.showedStatus
                )

                binaryCard(
                    title: "İçgüdüsel 'red flag' hissi oluştu mu?",
                    value: $vm.redFlag
                )

                VStack(alignment: .leading, spacing: 8) {
                    Text("Karşıya Verdiğin Puan")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.secondary)
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("\(vm.buildDateEvaluation().overallScore)")
                            .font(.system(size: 42, weight: .black))
                            .foregroundStyle(Color(hex: 0xFF2D55))
                        Text("/ 100")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color(.systemBackground))
                        .shadow(color: Color.black.opacity(0.04), radius: 12, x: 0, y: 6)
                )
            }
            .disabled(!vm.canSaveRating)
            .padding(.horizontal, 16)
            .padding(.bottom, 110)
        }
    }

    private var puanimPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Puanım")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(.primary)
                    .padding(.top, 6)

                Text("Karşı tarafın senin için verdiği değerlendirme (düzenlenemez).")
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)

                if let r = vm.receivedRating {
                    readonlySliderCard(
                        title: "Egosu ortamı bastırdı mı?",
                        value: r.egoScore,
                        minLabel: "MÜTEVAZI",
                        maxLabel: "TEK KİŞİLİK SAHNE"
                    )

                    readonlySliderCard(
                        title: "Samimiyet hissi nasıldı?",
                        value: r.sincerityScore,
                        minLabel: "TAMAMEN ROL",
                        maxLabel: "DOĞAL VE GERÇEK"
                    )

                    readonlySliderCard(
                        title: "Niyeti neydi?",
                        value: r.intentScore,
                        minLabel: "SADECE ETKİLEME",
                        maxLabel: "SENİ TANIMAYA ODAKLI"
                    )

                    readonlySliderCard(
                        title: "Sohbet akışı nasıldı?",
                        value: r.flowScore,
                        minLabel: "ZORLADI / AKMADI",
                        maxLabel: "DOĞAL / KEYİFLİ"
                    )

                    readonlySliderCard(
                        title: "Cinsel odak seviyesi nasıldı?",
                        value: r.sexualFocusScore,
                        minLabel: "HİÇ YOK",
                        maxLabel: "AŞIRI BASKIN"
                    )

                    readonlyBinaryCard(
                        title: "Para / statü gösterme ihtiyacı hissettirdi mi?",
                        value: r.showedStatus
                    )

                    readonlyBinaryCard(
                        title: "İçgüdüsel 'red flag' hissi oluştu mu?",
                        value: r.redFlag
                    )

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Karşı Tarafın Sana Verdiği Puan")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.secondary)
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text("\(r.overallScore)")
                                .font(.system(size: 42, weight: .black))
                                .foregroundStyle(Color(hex: 0x4C4ACA))
                            Text("/ 100")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(Color(.systemBackground))
                            .shadow(color: Color.black.opacity(0.04), radius: 12, x: 0, y: 6)
                    )
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Henüz değerlendirme yok")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.primary)
                        Text("Karşı taraf puanını kaydettiğinde burada otomatik görünecek.")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(Color(.systemBackground))
                            .shadow(color: Color.black.opacity(0.04), radius: 12, x: 0, y: 6)
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 110)
        }
    }

    private var forecastProfilesRow: some View {
        HStack(spacing: 22) {
            VStack(spacing: 8) {
                Circle()
                    .fill(Color(.systemBackground))
                    .overlay(
                        Group {
                            if let myAvatarUIImage = vm.myAvatarUIImage {
                                Image(uiImage: myAvatarUIImage)
                                    .resizable()
                                    .scaledToFill()
                            } else {
                                Image(systemName: "person.fill")
                                    .font(.system(size: 28, weight: .semibold))
                                    .foregroundStyle(Color(hex: 0xFF2D55))
                            }
                        }
                    )
                    .overlay(
                        Circle().stroke(Color(.systemBackground), lineWidth: 4)
                    )
                    .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 4)
                    .frame(width: 78, height: 78)
                    .clipShape(Circle())
                Text("Sen")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
            }

            ZStack {
                Circle()
                    .fill(Color(hex: 0xFF2D55).opacity(0.14))
                    .frame(width: 46, height: 46)
                Image(systemName: "sparkles")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color(hex: 0xFF2D55))
            }

            VStack(spacing: 8) {
                Circle()
                    .fill(Color(.systemBackground))
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundStyle(Color(hex: 0x4C4ACA))
                    )
                    .overlay(
                        Circle().stroke(Color(.systemBackground), lineWidth: 4)
                    )
                    .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 4)
                    .frame(width: 78, height: 78)
                Text(vm.partnerLabel)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var buzkiranPromptCards: [BuzkiranCardItem] {
        let palette: [(icon: String, strip: Color, bubble: Color)] = [
            ("bubble.left.and.bubble.right.fill", Color(hex: 0xE51245), Color(hex: 0xFFE8EE)),
            ("music.note", Color(hex: 0x6664E4), Color(hex: 0xEEF0FF)),
            ("fork.knife", Color(hex: 0x00855F), Color(hex: 0xE7F8F2)),
            ("airplane.departure", Color(hex: 0xF59E0B), Color(hex: 0xFFF4DF)),
        ]

        return vm.buzkiranItems.enumerated().map { idx, item in
            let p = palette[idx % palette.count]
            return BuzkiranCardItem(
                text: item.prompt,
                icon: p.icon,
                strip: p.strip,
                bubble: p.bubble
            )
        }
    }

    private var ongoruForecastCards: [ForecastCard] {
        vm.forecastItems.map { item in
            let p = forecastPalette(for: item.risk)
            return ForecastCard(
                title: item.title,
                text: item.text,
                icon: p.icon,
                tint: p.tint,
                badge: item.risk,
                badgeBackground: p.badgeBackground,
                badgeForeground: p.badgeForeground,
                tip: item.tip
            )
        }
    }

    private func forecastPalette(for risk: String) -> (
        icon: String,
        tint: Color,
        badgeBackground: Color,
        badgeForeground: Color
    ) {
        switch risk {
        case "DİKKAT":
            return (
                "creditcard.fill",
                Color(hex: 0xBA1A1A),
                Color(hex: 0xBA1A1A),
                .white
            )
        case "ORTA RİSK":
            return (
                "brain.head.profile",
                Color(hex: 0x4C4ACA),
                Color(hex: 0x4C4ACA).opacity(0.2),
                Color(hex: 0x4C4ACA)
            )
        default:
            return (
                "person.3.fill",
                Color(hex: 0x00694B),
                Color(hex: 0x00694B).opacity(0.2),
                Color(hex: 0x00694B)
            )
        }
    }

    private func reasonCard(title: String, text: String, icon: String, tint: Color) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle().fill(tint.opacity(0.12))
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(tint)
            }
            .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.primary)
                Text(text)
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.03), radius: 10, x: 0, y: 5)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color(.separator).opacity(0.22), lineWidth: 1)
        )
    }

    private func ongoruCard(item: ForecastCard) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 10) {
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(item.tint.opacity(0.12))
                        Image(systemName: item.icon)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(item.tint)
                    }
                    .frame(width: 38, height: 38)

                    Text(item.title)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.primary)
                }

                Spacer(minLength: 8)

                Text(item.badge)
                    .font(.system(size: 10, weight: .bold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(item.badgeBackground)
                    .foregroundStyle(item.badgeForeground)
                    .clipShape(Capsule())
            }

            Text(item.text)
                .font(.system(size: 15))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color(hex: 0xFF2D55))
                    Text("İletişim İpucu")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.primary)
                }
                Text(item.tip)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            .padding(12)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.04), radius: 14, x: 0, y: 8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color(.separator).opacity(0.22), lineWidth: 1)
        )
    }

    private func buzkiranCard(index: Int, item: BuzkiranCardItem) -> some View {
        HStack(alignment: .top, spacing: 12) {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(item.strip.opacity(0.5))
                .frame(width: 4)

            ZStack {
                Circle()
                    .fill(item.bubble)
                Image(systemName: item.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(item.strip)
            }
            .frame(width: 30, height: 30)

            Text(item.text)
                .font(.system(size: 15))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                UIPasteboard.general.string = item.text
                vm.copiedBuzkiranIndex = index
            } label: {
                Image(systemName: vm.copiedBuzkiranIndex == index ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(vm.copiedBuzkiranIndex == index ? Color(hex: 0xBA0034) : .secondary)
                    .frame(width: 36, height: 36)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.03), radius: 10, x: 0, y: 5)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color(.separator).opacity(0.2), lineWidth: 1)
        )
    }

    private func sliderCard(
        title: String,
        value: Binding<Double>,
        minLabel: String,
        maxLabel: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.primary)

            Slider(value: value, in: 1...10, step: 1)
                .tint(Color(hex: 0xBA0034))

            HStack {
                Text(minLabel)
                Spacer()
                Text(maxLabel)
            }
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.04), radius: 12, x: 0, y: 6)
        )
    }

    private func binaryCard(title: String, value: Binding<Bool>) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(.primary)

            HStack(spacing: 8) {
                Button {
                    value.wrappedValue = false
                } label: {
                    Text("Hayır")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(value.wrappedValue ? Color(.secondarySystemBackground) : Color(hex: 0xE9E7ED))
                        .foregroundStyle(.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)

                Button {
                    value.wrappedValue = true
                } label: {
                    Text("Evet")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(value.wrappedValue ? Color(hex: 0xE51245) : Color(.secondarySystemBackground))
                        .foregroundStyle(value.wrappedValue ? .white : .primary)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.04), radius: 12, x: 0, y: 6)
        )
    }

    private func readonlySliderCard(
        title: String,
        value: Int,
        minLabel: String,
        maxLabel: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.primary)
                Spacer()
                Text("\(value)/10")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color(hex: 0x4C4ACA))
            }

            ProgressView(value: Double(value), total: 10)
                .tint(Color(hex: 0x4C4ACA))

            HStack {
                Text(minLabel)
                Spacer()
                Text(maxLabel)
            }
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.04), radius: 12, x: 0, y: 6)
        )
    }

    private func readonlyBinaryCard(title: String, value: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(.primary)

            HStack(spacing: 8) {
                Text("Hayır")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(value ? Color(.secondarySystemBackground) : Color(hex: 0xE9E7ED))
                    .foregroundStyle(.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                Text("Evet")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(value ? Color(hex: 0x4C4ACA) : Color(.secondarySystemBackground))
                    .foregroundStyle(value ? .white : .primary)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.04), radius: 12, x: 0, y: 6)
        )
    }

}

private struct ForecastCard {
    let title: String
    let text: String
    let icon: String
    let tint: Color
    let badge: String
    let badgeBackground: Color
    let badgeForeground: Color
    let tip: String
}

private struct BuzkiranCardItem {
    let text: String
    let icon: String
    let strip: Color
    let bubble: Color
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

private extension Color {
    init(hex: UInt32, alpha: Double = 1.0) {
        let r = Double((hex & 0xFF0000) >> 16) / 255.0
        let g = Double((hex & 0x00FF00) >> 8) / 255.0
        let b = Double(hex & 0x0000FF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }
}

