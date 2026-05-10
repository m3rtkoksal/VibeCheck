import Foundation
import FirebaseFunctions

enum FriendlyCallableError {
    /// Human-readable text for Firebase Callable / OpenAI failures.
    static func message(for error: Error, label: String) -> String {
        if let auth = error as? HttpsCallableAuthError {
            return auth.localizedDescription ?? "Oturum doğrulanamadı."
        }

        if let ai = error as? AICompatibilityError, ai == .invalidResponse {
            return "\(label): sunucu cevabı okunamadı."
        }

        let ns = error as NSError
        if ns.domain == FunctionsErrorDomain,
           let code = FunctionsErrorCode(rawValue: ns.code) {
            let detail = ns.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
            switch code {
            case .resourceExhausted:
                return detail.isEmpty
                    ? "\(label): kotaya takıldık (OpenAI veya istek limiti)."
                    : "\(label): \(detail)"
            case .failedPrecondition:
                return detail.isEmpty
                    ? "\(label): önkoşul hatası (anahtar veya yapılandırma)."
                    : "\(label): \(detail)"
            case .unauthenticated:
                return "\(label): oturum yok. Uygulamayı yeniden açıp tekrar dene."
            case .permissionDenied:
                return "\(label): izin yok. Firebase Auth / kurallarını kontrol et."
            case .unavailable, .deadlineExceeded:
                return "\(label): servis geçici olarak kullanılamıyor. Biraz sonra tekrar dene."
            case .internal:
                return detail.isEmpty
                    ? "\(label): sunucu hatası (OpenAI veya arka uç)."
                    : "\(label): \(detail)"
            default:
                return detail.isEmpty
                    ? "\(label) başarısız (kod \(code.rawValue))."
                    : "\(label): \(detail)"
            }
        }

        return "\(label) başarısız: \(error.localizedDescription)"
    }
}
