import FirebaseAuth
import FirebaseCore
import Foundation

enum DiscoverabilityAuthService {
    static let uiDelegate = FirebaseAuthUIDelegateBridge()

    /// Firebase Phone Auth için E.164. Türkiye: `05xx…`, `90 5xx…`, `5xx…` (10 hane) → `+905xx…`
    static func normalizedE164Phone(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return trimmed }
        let compact = trimmed.replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
        if compact.hasPrefix("+") {
            return compact
        }
        let digits = String(compact.filter(\.isNumber))
        if digits.hasPrefix("05"), digits.count == 11 {
            return "+90" + String(digits.dropFirst())
        }
        if digits.hasPrefix("90"), digits.count == 12 {
            return "+" + digits
        }
        if digits.count == 10, digits.hasPrefix("5") {
            return "+90" + digits
        }
        return compact
    }

    /// SMS ile gönderilen doğrulama oturumu kimliği (bir sonraki adımda kod ile eşlenir).
    static func sendPhoneVerificationCode(to rawPhone: String) async throws -> String {
        try validateFirebaseBundleConfiguration()
        #if DEBUG && targetEnvironment(simulator)
        // Reinforce bypass only for Simulator test runs.
        Auth.auth().settings?.isAppVerificationDisabledForTesting = true
        #endif

        let formatted = normalizedE164Phone(rawPhone)
        guard !formatted.isEmpty else {
            throw NSError(
                domain: "DiscoverabilityAuth",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Telefon numarası boş."]
            )
        }

        let maxAttempts = 3
        var lastError: Error?

        for attempt in 1...maxAttempts {
            do {
                return try await verifyPhoneNumberOnce(formatted)
            } catch {
                lastError = error
                if !isTransientPhoneAuthError(error) || attempt == maxAttempts {
                    throw makePhoneAuthError(error)
                }
                let backoffNs = UInt64(attempt * attempt) * 600_000_000 // 0.6s, 2.4s
                try? await Task.sleep(nanoseconds: backoffNs)
            }
        }

        if let lastError {
            throw makePhoneAuthError(lastError)
        }
        throw NSError(
            domain: "DiscoverabilityAuth",
            code: 2,
            userInfo: [NSLocalizedDescriptionKey: "Doğrulama oturumu alınamadı."]
        )
    }

    static func linkPhone(verificationId: String, code: String) async throws {
        guard let user = Auth.auth().currentUser else {
            throw NSError(
                domain: "DiscoverabilityAuth",
                code: 3,
                userInfo: [NSLocalizedDescriptionKey: "Oturum yok."]
            )
        }
        let credential = PhoneAuthProvider.provider().credential(
            withVerificationID: verificationId,
            verificationCode: code.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        try await user.link(with: credential)
    }

    @MainActor
    static func linkTwitterAccount() async throws -> String? {
        guard let user = Auth.auth().currentUser else {
            throw NSError(
                domain: "DiscoverabilityAuth",
                code: 3,
                userInfo: [NSLocalizedDescriptionKey: "Oturum yok."]
            )
        }

        // Firebase Twitter oturumu OAuth 1.0a kullanır; OAuth 2 kapsamları (tweet.read vb.)
        // istekleri bozup dolaylı olarak doğrulama/akış hatalarına yol açabilir.
        let provider = OAuthProvider(providerID: "twitter.com")

        let credential = try await provider.credential(with: uiDelegate)
        let result = try await user.link(with: credential)

        // Twitter için "displayName" genelde isim/emoji gelir; arama için lazım olan handle’dır.
        if let u = result.additionalUserInfo?.username,
           let normalized = normalizedTwitterHandle(u) {
            return normalized
        }
        if let profile = result.additionalUserInfo?.profile as? [String: Any] {
            if let screen = profile["screen_name"] as? String,
               let normalized = normalizedTwitterHandle(screen) {
                return normalized
            }
            if let username = profile["username"] as? String,
               let normalized = normalizedTwitterHandle(username) {
                return normalized
            }
        }
        return nil
    }

    static func twitterUsername(from user: User) -> String? {
        for info in user.providerData where info.providerID == "twitter.com" {
            if let displayName = info.displayName,
               let normalized = normalizedTwitterHandle(displayName) {
                return normalized
            }
        }
        return nil
    }

    /// X handle'ını normalize eder: baştaki `@` kaldırılır, sadece `[a-zA-Z0-9_]` 1-15 kabul edilir.
    static func normalizedTwitterHandle(_ raw: String) -> String? {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        while s.hasPrefix("@") {
            s.removeFirst()
        }
        guard !s.isEmpty else { return nil }
        guard s.range(of: #"^[A-Za-z0-9_]{1,15}$"#, options: .regularExpression) != nil else {
            return nil
        }
        return s.lowercased()
    }

    static func unlinkTwitter() async throws {
        guard let user = Auth.auth().currentUser else { return }
        _ = try await user.unlink(fromProvider: "twitter.com")
    }

    static func unlinkPhone() async throws {
        guard let user = Auth.auth().currentUser else { return }
        _ = try await user.unlink(fromProvider: PhoneAuthProviderID)
    }

    static func phoneAuthErrorMessage(_ error: Error) -> String {
        let ns = error as NSError
        let fallback = ns.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)

        if isTransientPhoneAuthError(error) {
            return "SMS doğrulama servisi şu an yoğun görünüyor (geçici 503). 30-60 saniye sonra tekrar dene."
        }

        if ns.domain == AuthErrorDomain,
           let code = AuthErrorCode(rawValue: ns.code) {
            switch code {
            case .webContextCancelled:
                return "Doğrulama ekranını kapattığın için işlem iptal edildi."
            case .invalidPhoneNumber:
                return "Telefon numarası geçersiz görünüyor. +90 5xx xxx xx xx formatında tekrar dene."
            case .quotaExceeded, .tooManyRequests:
                return "Çok sık deneme yapıldı. Birkaç dakika sonra tekrar dene."
            case .networkError:
                return "Ağ bağlantısı hatası. İnterneti kontrol edip tekrar dene."
            case .invalidAppCredential, .appNotAuthorized:
                return """
                Firebase Phone Auth yapılandırması bu uygulama kimliğiyle eşleşmiyor.
                Firebase Console'da iOS app olarak `\(Bundle.main.bundleIdentifier ?? "-")` kaydını kontrol et ve doğru `GoogleService-Info.plist` dosyasını tekrar indir.
                """
            case .internalError:
                return """
                Firebase doğrulaması iç hata verdi.
                Bu hata çoğunlukla iOS app konfigürasyonu (bundle id / plist) uyuşmazlığı
                veya APNs/reCAPTCHA app verification akışının takılması nedeniyle olur.
                Debug build'de test bypass açıkken gerçek numarayla deniyorsan yine de Firebase test numarasıyla doğrulaman daha stabil olur.
                """
            default:
                break
            }
        }

        if fallback.lowercased().contains("internal error has occurred") {
            return """
            Firebase doğrulaması iç hata verdi.
            En sık sebepler: Firebase iOS app konfigürasyon uyumsuzluğu veya Simulator doğrulama akışı.
            Bundle id / `GoogleService-Info.plist` eşleşmesini kontrol et, mümkünse gerçek cihazda tekrar dene.
            """
        }

        if fallback.lowercased().contains("does not contain a client identifier") {
            let expectedScheme = expectedFirebaseURLScheme() ?? "app-<GOOGLE_APP_ID with ':' replaced by '-'>"
            return """
            Firebase isteğinde client identifier eksik görünüyor.
            `AppInfo.plist` içinde bu URL scheme kayıtlı olmalı: \(expectedScheme)
            Ayrıca temiz build (Clean Build Folder) + uygulamayı silip yeniden kur yap.
            """
        }

        if fallback.isEmpty {
            return "Doğrulama sırasında beklenmeyen bir hata oluştu. [\(ns.domain) code=\(ns.code)]"
        }
        return "\(fallback) [\(ns.domain) code=\(ns.code)]"
    }

    private static func validateFirebaseBundleConfiguration() throws {
        guard let currentBundleID = Bundle.main.bundleIdentifier,
              !currentBundleID.isEmpty else { return }

        guard let configuredBundleID = FirebaseApp.app()?.options.bundleID,
              !configuredBundleID.isEmpty else { return }

        guard configuredBundleID == currentBundleID else {
            throw NSError(
                domain: "DiscoverabilityAuth",
                code: 1001,
                userInfo: [
                    NSLocalizedDescriptionKey:
                        """
                        Firebase konfigürasyonu bu build ile uyuşmuyor.
                        Mevcut bundle id: \(currentBundleID)
                        GoogleService-Info.plist bundle id: \(configuredBundleID)
                        Firebase Console'dan doğru iOS uygulaması için plist indirip projedeki dosyayı değiştir.
                        """
                ]
            )
        }
    }

    private static func verifyPhoneNumberOnce(_ formatted: String) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            PhoneAuthProvider.provider().verifyPhoneNumber(
                formatted,
                uiDelegate: nil
            ) { verificationID, error in
                if let error {
                    logAuthError(error, context: "PhoneAuth.verifyPhoneNumber")
                    continuation.resume(throwing: error)
                    return
                }
                guard let verificationID else {
                    continuation.resume(throwing: NSError(
                        domain: "DiscoverabilityAuth",
                        code: 2,
                        userInfo: [NSLocalizedDescriptionKey: "Doğrulama oturumu alınamadı."]
                    ))
                    return
                }
                continuation.resume(returning: verificationID)
            }
        }
    }

    private static func isTransientPhoneAuthError(_ error: Error) -> Bool {
        let ns = error as NSError
        let infoDump = String(describing: ns.userInfo).lowercased()
        let message = ns.localizedDescription.lowercased()
        return infoDump.contains("code = 503")
            || infoDump.contains("error code: 39")
            || infoDump.contains("backenderror")
            || message.contains("error code: 39")
    }

    private static func makePhoneAuthError(_ error: Error) -> NSError {
        let message = phoneAuthErrorMessage(error)
        let ns = error as NSError
        return NSError(
            domain: ns.domain,
            code: ns.code,
            userInfo: [NSLocalizedDescriptionKey: message]
        )
    }

    private static func expectedFirebaseURLScheme() -> String? {
        guard let googleAppID = FirebaseApp.app()?.options.googleAppID, !googleAppID.isEmpty else {
            return nil
        }
        return "app-" + googleAppID.replacingOccurrences(of: ":", with: "-")
    }

    static func logAuthError(_ error: Error, context: String) {
        let ns = error as NSError
        let detail = ns.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        let codeText: String
        if ns.domain == AuthErrorDomain, let authCode = AuthErrorCode(rawValue: ns.code) {
            codeText = "\(ns.code) (\(authCode))"
        } else {
            codeText = "\(ns.code)"
        }

        NSLog("[Auth][%@] domain=%@ code=%@ message=%@", context, ns.domain, codeText, detail)

        if !ns.userInfo.isEmpty {
            NSLog("[Auth][%@] userInfo=%@", context, String(describing: ns.userInfo))
        }
    }
}
