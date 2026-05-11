import Foundation
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage

@MainActor
final class SettingsDetailViewModel: ObservableObject {
    // MARK: - Persisted (AppStorage equivalents)
    @Published var phoneNumber: String { didSet { defaults.set(phoneNumber, forKey: Keys.phoneNumber) } }
    @Published var phoneDiscoverable: Bool {
        didSet { defaults.set(phoneDiscoverable, forKey: Keys.phoneDiscoverable) }
    }
    @Published var phoneVerified: Bool { didSet { defaults.set(phoneVerified, forKey: Keys.phoneVerified) } }

    @Published var xUsername: String { didSet { defaults.set(xUsername, forKey: Keys.xUsername) } }
    @Published var xDiscoverable: Bool { didSet { defaults.set(xDiscoverable, forKey: Keys.xDiscoverable) } }
    @Published var xVerified: Bool { didSet { defaults.set(xVerified, forKey: Keys.xVerified) } }
    @Published var fullName: String { didSet { defaults.set(fullName, forKey: Keys.fullName) } }

    // MARK: - UI state
    @Published var verificationId: String?
    @Published var otpCode = ""
    @Published var showOtpPrompt = false
    @Published var isBusy = false
    @Published var alertMessage = ""
    @Published var showAlert = false

    private let defaults: UserDefaults
    private var hasShownFirestoreApiAlert = false

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        self.phoneNumber = defaults.string(forKey: Keys.phoneNumber) ?? ""
        self.phoneDiscoverable = defaults.bool(forKey: Keys.phoneDiscoverable)
        self.phoneVerified = defaults.bool(forKey: Keys.phoneVerified)

        self.xUsername = defaults.string(forKey: Keys.xUsername) ?? ""
        self.xDiscoverable = defaults.bool(forKey: Keys.xDiscoverable)
        self.xVerified = defaults.bool(forKey: Keys.xVerified)
        self.fullName = defaults.string(forKey: Keys.fullName) ?? ""
    }

    func syncFromFirebaseUser() {
        guard let user = Auth.auth().currentUser else { return }
        if let phone = user.phoneNumber, !phone.isEmpty {
            phoneNumber = phone
            phoneVerified = true
        }
        if let tw = DiscoverabilityAuthService.twitterUsername(from: user) {
            xUsername = tw
            xVerified = true
        }
        if trimmed(fullName).isEmpty,
           let displayName = user.displayName,
           !trimmed(displayName).isEmpty {
            fullName = displayName
        }
    }

    /// Compatibility ekranında telefon / X / vibeCode ile arama ve Geçmiş avatarı için minimal index.
    /// Yazılan alanlar: `vibeCode`, `phoneE164`, `xUsernameLower`, `fullName`, `photoPublicURL` (Storage ile).
    func syncDiscoverabilityIndex() async {
        guard let user = Auth.auth().currentUser else { return }

        let phoneToPublish: String? = (phoneVerified && phoneDiscoverable) ? user.phoneNumber : nil
        let xToPublish: String? = (xVerified && xDiscoverable)
            ? DiscoverabilityAuthService.normalizedTwitterHandle(xUsername)
            : nil

        let vibeCode = (try? VibeCode.encode(ProfileSnapshot.fromLocalDefaults())) ?? ""
        var data: [String: Any] = [
            "vibeCode": vibeCode,
            "updatedAt": FieldValue.serverTimestamp(),
        ]

        let cleanedName = trimmed(fullName)
        if !cleanedName.isEmpty {
            data["fullName"] = cleanedName
        } else {
            data["fullName"] = FieldValue.delete()
        }

        if let phoneToPublish {
            data["phoneE164"] = phoneToPublish
        } else {
            data["phoneE164"] = FieldValue.delete()
        }

        if let xToPublish {
            data["xUsernameLower"] = xToPublish
        } else {
            data["xUsernameLower"] = FieldValue.delete()
        }

        await mergePublicDiscoverabilityAvatar(for: user.uid, into: &data)

        do {
            try await withTimeout(seconds: 4) {
                try await Firestore.firestore()
                    .collection("discoverabilityUsers")
                    .document(user.uid)
                    .setData(data, merge: true)
            }
        } catch {
            handleIndexSyncError(error)
        }
    }

    func sendSms() async {
        isBusy = true
        defer { isBusy = false }
        do {
            let id = try await DiscoverabilityAuthService.sendPhoneVerificationCode(to: phoneNumber)
            verificationId = id
            otpCode = ""
            showOtpPrompt = true
        } catch {
            DiscoverabilityAuthService.logAuthError(error, context: "SettingsDetailViewModel.sendSms")
            alertMessage = DiscoverabilityAuthService.phoneAuthErrorMessage(error)
            showAlert = true
        }
    }

    func verifyPhoneOtp() async {
        guard let vid = verificationId else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            try await DiscoverabilityAuthService.linkPhone(verificationId: vid, code: otpCode)
            otpCode = ""
            verificationId = nil
            showOtpPrompt = false
            phoneVerified = true
            if let p = Auth.auth().currentUser?.phoneNumber {
                phoneNumber = p
            }
            Task { await syncDiscoverabilityIndex() }
        } catch {
            DiscoverabilityAuthService.logAuthError(error, context: "SettingsDetailViewModel.verifyPhoneOtp")
            alertMessage = DiscoverabilityAuthService.phoneAuthErrorMessage(error)
            showAlert = true
        }
    }

    func unlinkPhone() async {
        isBusy = true
        defer { isBusy = false }
        do {
            try await DiscoverabilityAuthService.unlinkPhone()
            phoneVerified = false
            phoneDiscoverable = false
            phoneNumber = ""
            Task { await syncDiscoverabilityIndex() }
        } catch {
            alertMessage = error.localizedDescription
            showAlert = true
        }
    }

    func linkTwitter() async {
        isBusy = true
        defer { isBusy = false }
        do {
            let handle = try await DiscoverabilityAuthService.linkTwitterAccount()
            syncFromFirebaseUser()
            xVerified = true
            if let handle {
                xUsername = handle
            }
            Task { await syncDiscoverabilityIndex() }
        } catch {
            alertMessage = error.localizedDescription
            showAlert = true
        }
    }

    func unlinkTwitter() async {
        isBusy = true
        defer { isBusy = false }
        do {
            try await DiscoverabilityAuthService.unlinkTwitter()
            xVerified = false
            xUsername = ""
            xDiscoverable = false
            Task { await syncDiscoverabilityIndex() }
        } catch {
            alertMessage = error.localizedDescription
            showAlert = true
        }
    }

    func trimmed(_ s: String) -> String {
        s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func withTimeout<T>(
        seconds: UInt64,
        operation: @escaping () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask { try await operation() }
            group.addTask {
                try await Task.sleep(nanoseconds: seconds * 1_000_000_000)
                throw NSError(
                    domain: "DiscoverabilityIndex",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "Index yazımı zaman aşımına uğradı."]
                )
            }
            defer { group.cancelAll() }
            return try await group.next()!
        }
    }

    private enum Keys {
        static let phoneNumber = "discoverability.phoneNumber"
        static let phoneDiscoverable = "discoverability.phoneDiscoverable"
        static let phoneVerified = "discoverability.phoneVerified"
        static let xUsername = "discoverability.xUsername"
        static let xDiscoverable = "discoverability.xDiscoverable"
        static let xVerified = "discoverability.xVerified"
        static let fullName = "discoverability.fullName"
        static let profilePhotoSaved = "profile.photoSaved"
    }

    private static let publicAvatarStoragePathFormat = "discoverability_public_avatars/%@.jpg"

    /// Küçük public avatar: Storage + `photoPublicURL` (Geçmiş’te AsyncImage için).
    private func mergePublicDiscoverabilityAvatar(for uid: String, into data: inout [String: Any]) async {
        let saved = defaults.bool(forKey: Keys.profilePhotoSaved)
        let path = String(format: Self.publicAvatarStoragePathFormat, uid)
        let ref = Storage.storage().reference(withPath: path)

        if saved {
            guard let jpeg = ProfilePhotoStore.jpegDataForPublicDiscoverability() else { return }
            do {
                let meta = StorageMetadata()
                meta.contentType = "image/jpeg"
                _ = try await ref.putDataAsync(jpeg, metadata: meta)
                let url = try await firebaseStorageDownloadURL(ref)
                data["photoPublicURL"] = url.absoluteString
            } catch {
                NSLog("Discoverability avatar yükleme hatası: %@", String(describing: error))
            }
        } else {
            data["photoPublicURL"] = FieldValue.delete()
            await firebaseStorageDeleteIgnoringError(ref)
        }
    }

    private func firebaseStorageDownloadURL(_ ref: StorageReference) async throws -> URL {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL, Error>) in
            ref.downloadURL { url, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let url else {
                    continuation.resume(throwing: NSError(
                        domain: "FirebaseStorage",
                        code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "Boş indirme URL’si."]
                    ))
                    return
                }
                continuation.resume(returning: url)
            }
        }
    }

    private func firebaseStorageDeleteIgnoringError(_ ref: StorageReference) async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            ref.delete { _ in
                continuation.resume()
            }
        }
    }

    private func handleIndexSyncError(_ error: Error) {
        let message = error.localizedDescription.lowercased()
        let firestoreApiDisabled =
            message.contains("firestore.googleapis.com")
            || message.contains("cloud firestore api has not been used")
            || message.contains("permission denied")
            || message.contains("the database (default) does not exist")
            || message.contains("datastore/setup")

        guard firestoreApiDisabled, !hasShownFirestoreApiAlert else { return }
        hasShownFirestoreApiAlert = true
        alertMessage = """
        Firestore veritabanı hazır görünmüyor. Lütfen 'vibecheck-4916b' projesinde \
        Firestore database (default) oluşturup birkaç dakika bekleyin.
        """
        showAlert = true
    }
}

