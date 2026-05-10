import FirebaseFirestore
import Foundation

@MainActor
final class CompatibilityAnalysisViewModel: ObservableObject {
    @Published var myCode: String = ""
    @Published var partnerQuery: String = ""
    @Published var errorText: String?
    @Published var output: AIOnlyAnalysisOutput?
    @Published var isAnalyzing = false

    func generateMyCode() {
        do {
            myCode = try VibeCode.encode(ProfileSnapshot.fromLocalDefaults())
        } catch {
            myCode = "vbc1.error"
        }
    }

    func runCombinedAnalysis(privateNote: String) async {
        errorText = nil
        output = nil
        isAnalyzing = true
        defer { isAnalyzing = false }

        do {
            let canonicalPartner = trimmed(partnerQuery)
            let partner = try await resolvePartnerSnapshot(from: canonicalPartner)
            let me = ProfileSnapshot.fromLocalDefaults()
            let aiResult = try await AICompatibilityService.analyzeViaFirebase(
                me: me,
                partner: partner,
                privateNote: privateNote
            )
            // Firestore publish + geçmiş eşlemesi için TAM vibe code / telefon / @kullanıcı gerekir;
            // maskelenmiş "vbc1.xxx...yyy" ile discoverabilityUsers sorgusu eşleşmez.
            let result = AIOnlyAnalysisOutput(
                partnerQuery: canonicalPartner,
                ai: aiResult
            )
            output = result
        } catch {
            if error is VibeCodeError || (error as NSError).domain == "Compatibility" {
                errorText = friendlyPartnerResolveError(error)
            } else {
                errorText = FriendlyCallableError.message(for: error, label: "AI analizi")
            }
        }
    }

    var maskedMyCodePreview: String {
        let code = myCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !code.isEmpty else { return "vbc1x9...4k2p" }
        guard code.count > 10 else { return code }
        let prefix = String(code.prefix(6))
        let suffix = String(code.suffix(4))
        return "\(prefix)...\(suffix)"
    }

    private func trimmed(_ s: String) -> String {
        s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func resolvePartnerSnapshot(from input: String) async throws -> ProfileSnapshot {
        let q = trimmed(input)
        if q.hasPrefix("vbc1.") {
            return try VibeCode.decode(q)
        }

        let normalizedPhone = DiscoverabilityAuthService.normalizedE164Phone(q)
        if normalizedPhone.hasPrefix("+"), normalizedPhone.count >= 8 {
            if let code = try await lookupVibeCodeBy(field: "phoneE164", value: normalizedPhone) {
                return try VibeCode.decode(code)
            }
            throw NSError(
                domain: "Compatibility",
                code: 100,
                userInfo: [NSLocalizedDescriptionKey: "Bu telefon numarasıyla kayıtlı bir Vibe Code bulunamadı."]
            )
        }

        let rawUser = q.hasPrefix("@") ? String(q.dropFirst()) : q
        let username = rawUser.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !username.isEmpty,
           username.range(of: #"^[a-z0-9_]{1,15}$"#, options: .regularExpression) != nil {
            if let code = try await lookupVibeCodeBy(field: "xUsernameLower", value: username) {
                return try VibeCode.decode(code)
            }
            throw NSError(
                domain: "Compatibility",
                code: 101,
                userInfo: [NSLocalizedDescriptionKey: "Bu X kullanıcı adıyla kayıtlı bir Vibe Code bulunamadı."]
            )
        }

        throw NSError(
            domain: "Compatibility",
            code: 102,
            userInfo: [NSLocalizedDescriptionKey: "Girdi anlaşılamadı. “vbc1…” kodu, telefon (+90…) veya X kullanıcı adı (@…) gir."]
        )
    }

    private func lookupVibeCodeBy(field: String, value: String) async throws -> String? {
        let db = Firestore.firestore()
        do {
            let snap = try await db
                .collection("discoverabilityUsers")
                .whereField(field, isEqualTo: value)
                .limit(to: 1)
                .getDocuments()
            return snap.documents.first?.data()["vibeCode"] as? String
        } catch {
            if isMissingFirestoreDatabaseError(error) {
                throw NSError(
                    domain: "Compatibility",
                    code: 150,
                    userInfo: [NSLocalizedDescriptionKey:
                        "Firestore veritabanı henüz oluşturulmamış. Firebase Console'dan Firestore'u etkinleştirip tekrar dene."
                    ]
                )
            }
            throw error
        }
    }

    private func lookupDiscoverabilityBy(vibeCode: String) async throws -> [String: Any]? {
        let db = Firestore.firestore()
        do {
            let snap = try await db
                .collection("discoverabilityUsers")
                .whereField("vibeCode", isEqualTo: vibeCode)
                .limit(to: 1)
                .getDocuments()
            return snap.documents.first?.data()
        } catch {
            if isMissingFirestoreDatabaseError(error) {
                throw NSError(
                    domain: "Compatibility",
                    code: 150,
                    userInfo: [NSLocalizedDescriptionKey:
                        "Firestore veritabanı henüz oluşturulmamış. Firebase Console'dan Firestore'u etkinleştirip tekrar dene."
                    ]
                )
            }
            throw error
        }
    }

    private func friendlyPartnerResolveError(_ error: Error) -> String {
        if let codeErr = error as? VibeCodeError {
            switch codeErr {
            case .invalidPrefix:
                return "Kod formatı geçersiz. Kodun “vbc1.” ile başlaması lazım."
            case .invalidBase64:
                return "Kod bozuk görünüyor. Tam kopyaladığından emin ol."
            }
        }
        return error.localizedDescription
    }

    private func isMissingFirestoreDatabaseError(_ error: Error) -> Bool {
        let message = (error as NSError).localizedDescription.lowercased()
        return message.contains("the database (default) does not exist")
            || message.contains("please visit https://console.cloud.google.com/datastore/setup")
            || message.contains("cloud firestore database")
    }
}
