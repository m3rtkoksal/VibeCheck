import Foundation

enum ProfileCategory: String, CaseIterable, Identifiable {
    case messageTempo
    case repairAfterConflict
    case boundaryStyle
    case closenessNeed
    case jealousyTrigger

    var id: String { rawValue }

    var title: String {
        switch self {
        case .messageTempo:
            "Partner mesajına geç dönme"
        case .repairAfterConflict:
            "Küçük bir tartışma çıktı"
        case .boundaryStyle:
            "Bir konuda kırıldın"
        case .closenessNeed:
            "Yeni biriyle tanışıyorsun"
        case .jealousyTrigger:
            "Partnerin karşı cins bir arkadaşıyla sık görüşüyor"
        }
    }

    var options: [String] {
        switch self {
        case .messageTempo:
            return [
                "Pek umursamam, müsait değildir diye düşünürüm",
                "Biraz merak ederim ama sorun etmem",
                "Neden geç kaldığını sorgularım",
            ]
        case .repairAfterConflict:
            return [
                "Konuyu kapatıp uzaklaşırım",
                "Sakinleşince konuşur çözmeye çalışırım",
                "O an konuşup halletmek isterim",
            ]
        case .boundaryStyle:
            return [
                "Çok takmam, geçer",
                "Uygun zamanda söylerim",
                "İçimde kalır, kolay geçmez",
            ]
        case .closenessNeed:
            return [
                "Zamanla açılırım",
                "Dengeli ilerlerim",
                "Hızlı yakınlaşırım",
            ]
        case .jealousyTrigger:
            return [
                "Doğal karşılarım",
                "Sınırlar önemli olur",
                "Rahatsızlık hissederim",
            ]
        }
    }
}
