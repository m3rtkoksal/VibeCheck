import SwiftUI

struct PuanimResultTabContent: View {
    @ObservedObject var vm: CompatibilityAnalysisResultViewModel

    var body: some View {
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
                    CompatibilityResultReadonlySliderCard(
                        title: "Egosu ortamı bastırdı mı?",
                        value: r.egoScore,
                        minLabel: "MÜTEVAZI",
                        maxLabel: "TEK KİŞİLİK SAHNE"
                    )

                    CompatibilityResultReadonlySliderCard(
                        title: "Samimiyet hissi nasıldı?",
                        value: r.sincerityScore,
                        minLabel: "TAMAMEN ROL",
                        maxLabel: "DOĞAL VE GERÇEK"
                    )

                    CompatibilityResultReadonlySliderCard(
                        title: "Niyeti neydi?",
                        value: r.intentScore,
                        minLabel: "SADECE ETKİLEME",
                        maxLabel: "SENİ TANIMAYA ODAKLI"
                    )

                    CompatibilityResultReadonlySliderCard(
                        title: "Sohbet akışı nasıldı?",
                        value: r.flowScore,
                        minLabel: "ZORLADI / AKMADI",
                        maxLabel: "DOĞAL / KEYİFLİ"
                    )

                    CompatibilityResultReadonlySliderCard(
                        title: "Cinsel odak seviyesi nasıldı?",
                        value: r.sexualFocusScore,
                        minLabel: "HİÇ YOK",
                        maxLabel: "AŞIRI BASKIN"
                    )

                    CompatibilityResultReadonlyBinaryCard(
                        title: "Para / statü gösterme ihtiyacı hissettirdi mi?",
                        value: r.showedStatus
                    )

                    CompatibilityResultReadonlyBinaryCard(
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
                                .foregroundStyle(Color(crHex: 0x4C4ACA))
                            Text("/ 100")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .resultGlassCard(cornerRadius: 20, shadowRadius: 12, shadowY: 6)
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
                    .resultGlassCard(cornerRadius: 20, shadowRadius: 12, shadowY: 6)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 110)
        }
    }
}
