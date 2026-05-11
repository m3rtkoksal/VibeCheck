import SwiftUI

struct DegerlendirmeResultTabContent: View {
    @ObservedObject var vm: CompatibilityAnalysisResultViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Randevu Değerlendirmesi")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(.primary)
                    .padding(.top, 6)

                Text("Bu bilgiler tamamen gizlidir ve sadece AI analizi için kullanılır.")
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)

                CompatibilityResultSliderCard(
                    title: "Egosu ortamı bastırdı mı?",
                    value: $vm.egoScore,
                    minLabel: "MÜTEVAZI",
                    maxLabel: "TEK KİŞİLİK SAHNE"
                )

                CompatibilityResultSliderCard(
                    title: "Samimiyet hissi nasıldı?",
                    value: $vm.sincerityScore,
                    minLabel: "TAMAMEN ROL",
                    maxLabel: "DOĞAL VE GERÇEK"
                )

                CompatibilityResultSliderCard(
                    title: "Niyeti neydi?",
                    value: $vm.intentScore,
                    minLabel: "SADECE ETKİLEME",
                    maxLabel: "SENİ TANIMAYA ODAKLI"
                )

                CompatibilityResultSliderCard(
                    title: "Sohbet akışı nasıldı?",
                    value: $vm.flowScore,
                    minLabel: "ZORLADI / AKMADI",
                    maxLabel: "DOĞAL / KEYİFLİ"
                )

                CompatibilityResultSliderCard(
                    title: "Cinsel odak seviyesi nasıldı?",
                    value: $vm.sexualFocusScore,
                    minLabel: "HİÇ YOK",
                    maxLabel: "AŞIRI BASKIN"
                )

                CompatibilityResultBinaryChoiceCard(
                    title: "Para / statü gösterme ihtiyacı hissettirdi mi?",
                    value: $vm.showedStatus
                )

                CompatibilityResultBinaryChoiceCard(
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
                            .foregroundStyle(Color(crHex: 0x3B82F6))
                        Text("/ 100")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .resultGlassCard(cornerRadius: 20, shadowRadius: 12, shadowY: 6)
            }
            .disabled(!vm.canSaveRating)
            .padding(.horizontal, 16)
            .padding(.bottom, 110)
        }
    }
}
