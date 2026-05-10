import AuthenticationServices
import CryptoKit
import FirebaseAuth
import Foundation
import Security

@MainActor
final class LoginViewModel: ObservableObject {
    /// TR ulusal numara: 10 hane (örn. 5555225212). UI `+90` sabit gösterir.
    @Published var phoneNationalNumber = "" {
        didSet {
            let normalized = normalizeTRNationalNumber(phoneNationalNumber)
            if normalized != phoneNationalNumber {
                phoneNationalNumber = normalized
            }
        }
    }
    @Published var otpCode = ""
    @Published var showOtpPrompt = false
    @Published var isBusy = false
    @Published var alertMessage = ""
    @Published var showAlert = false

    private var verificationId: String?
    private var currentNonce: String?

    private var phoneE164: String {
        let digits = phoneNationalNumber.filter(\.isNumber)
        return "+90" + digits
    }

    func startPhoneLogin() async {
        isBusy = true
        defer { isBusy = false }
        do {
            phoneNationalNumber = normalizeTRNationalNumber(phoneNationalNumber)
            let digits = phoneNationalNumber.filter(\.isNumber)
            guard digits.count == 10, digits.hasPrefix("5") else {
                throw NSError(
                    domain: "Login",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "Telefon numarası 10 hane olmalı (555… gibi)."]
                )
            }

            let id = try await DiscoverabilityAuthService.sendPhoneVerificationCode(to: phoneE164)
            verificationId = id
            otpCode = ""
            showOtpPrompt = true
        } catch {
            DiscoverabilityAuthService.logAuthError(error, context: "LoginViewModel.startPhoneLogin")
            alertMessage = DiscoverabilityAuthService.phoneAuthErrorMessage(error)
            showAlert = true
        }
    }

    func updatePhoneInput(_ raw: String) {
        phoneNationalNumber = normalizeTRNationalNumber(raw)
    }

    func confirmPhoneLogin() async -> User? {
        guard let vid = verificationId else { return nil }
        isBusy = true
        defer { isBusy = false }
        do {
            let credential = PhoneAuthProvider.provider().credential(
                withVerificationID: vid,
                verificationCode: otpCode.trimmingCharacters(in: .whitespacesAndNewlines)
            )

            if let current = Auth.auth().currentUser, current.isAnonymous {
                do {
                    _ = try await current.link(with: credential)
                } catch {
                    let ns = error as NSError
                    if ns.domain == AuthErrorDomain,
                       let code = AuthErrorCode(rawValue: ns.code),
                       code == .credentialAlreadyInUse {
                        // This phone number already belongs to another user → treat as login instead of register/link.
                        _ = try await Auth.auth().signIn(with: credential)
                    } else {
                        throw error
                    }
                }
            } else {
                _ = try await Auth.auth().signIn(with: credential)
            }

            otpCode = ""
            verificationId = nil
            showOtpPrompt = false
            return Auth.auth().currentUser
        } catch {
            DiscoverabilityAuthService.logAuthError(error, context: "LoginViewModel.confirmPhoneLogin")
            alertMessage = DiscoverabilityAuthService.phoneAuthErrorMessage(error)
            showAlert = true
            return nil
        }
    }

    func loginWithTwitter() async -> User? {
        isBusy = true
        defer { isBusy = false }
        do {
            let provider = OAuthProvider(providerID: "twitter.com")
            let credential = try await provider.credential(with: DiscoverabilityAuthService.uiDelegate)

            if let current = Auth.auth().currentUser, current.isAnonymous {
                do {
                    _ = try await current.link(with: credential)
                } catch {
                    let ns = error as NSError
                    if ns.domain == AuthErrorDomain,
                       let code = AuthErrorCode(rawValue: ns.code),
                       code == .credentialAlreadyInUse {
                        _ = try await Auth.auth().signIn(with: credential)
                    } else {
                        throw error
                    }
                }
            } else {
                _ = try await Auth.auth().signIn(with: credential)
            }

            return Auth.auth().currentUser
        } catch {
            DiscoverabilityAuthService.logAuthError(error, context: "LoginViewModel.loginWithTwitter")
            alertMessage = error.localizedDescription
            showAlert = true
            return nil
        }
    }

    func prepareAppleSignIn(_ request: ASAuthorizationAppleIDRequest) {
        let nonce = randomNonceString()
        currentNonce = nonce
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)
    }

    func handleAppleSignIn(result: Result<ASAuthorization, Error>) async -> User? {
        isBusy = true
        defer { isBusy = false }

        do {
            guard case let .success(authResult) = result else {
                if case let .failure(error) = result { throw error }
                throw NSError(
                    domain: "AppleSignIn",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Apple ile giriş tamamlanamadı."]
                )
            }

            guard let credential = authResult.credential as? ASAuthorizationAppleIDCredential else {
                throw NSError(
                    domain: "AppleSignIn",
                    code: -2,
                    userInfo: [NSLocalizedDescriptionKey: "Apple kimlik bilgisi alınamadı."]
                )
            }

            guard let nonce = currentNonce else {
                throw NSError(
                    domain: "AppleSignIn",
                    code: -3,
                    userInfo: [NSLocalizedDescriptionKey: "Apple giriş oturumu geçersiz."]
                )
            }

            guard let tokenData = credential.identityToken,
                  let idTokenString = String(data: tokenData, encoding: .utf8) else {
                throw NSError(
                    domain: "AppleSignIn",
                    code: -4,
                    userInfo: [NSLocalizedDescriptionKey: "Apple kimlik doğrulama token'ı okunamadı."]
                )
            }

            let firebaseCredential = OAuthProvider.appleCredential(
                withIDToken: idTokenString,
                rawNonce: nonce,
                fullName: credential.fullName
            )

            if let current = Auth.auth().currentUser, current.isAnonymous {
                do {
                    _ = try await current.link(with: firebaseCredential)
                } catch {
                    let ns = error as NSError
                    if ns.domain == AuthErrorDomain,
                       let code = AuthErrorCode(rawValue: ns.code),
                       code == .credentialAlreadyInUse {
                        _ = try await Auth.auth().signIn(with: firebaseCredential)
                    } else {
                        throw error
                    }
                }
            } else {
                _ = try await Auth.auth().signIn(with: firebaseCredential)
            }

            currentNonce = nil
            return Auth.auth().currentUser
        } catch {
            DiscoverabilityAuthService.logAuthError(error, context: "LoginViewModel.handleAppleSignIn")
            alertMessage = error.localizedDescription
            showAlert = true
            return nil
        }
    }

    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashed = SHA256.hash(data: inputData)
        return hashed.compactMap { String(format: "%02x", $0) }.joined()
    }

    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length

        while remainingLength > 0 {
            var randoms: [UInt8] = Array(repeating: 0, count: 16)
            let errorCode = SecRandomCopyBytes(kSecRandomDefault, randoms.count, &randoms)
            if errorCode != errSecSuccess {
                fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
            }

            randoms.forEach { random in
                if remainingLength == 0 { return }
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }

        return result
    }

    private func normalizeTRNationalNumber(_ input: String) -> String {
        let digits = input.filter(\.isNumber)
        if digits.hasPrefix("90"), digits.count >= 12 {
            return String(digits.dropFirst(2).prefix(10))
        }
        if digits.hasPrefix("0"), digits.count >= 11 {
            return String(digits.dropFirst(1).prefix(10))
        }
        return String(digits.prefix(10))
    }
}

