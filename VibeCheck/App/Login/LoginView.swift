import AuthenticationServices
import FirebaseAuth
import SwiftUI

struct LoginView: View {
    @Binding var isLoggedIn: Bool
    @Environment(\.colorScheme) private var colorScheme

    @AppStorage("auth.provider") private var providerRawValue = ""
    @AppStorage("auth.userId") private var userId = ""

    @StateObject private var vm = LoginViewModel()

    var body: some View {
        NavigationStack {
            loginRoot
                .toolbar(.hidden, for: .navigationBar)
        }
        .tint(Color(hex: 0xE51245))
        .disabled(vm.isBusy)
        .overlay {
            if vm.isBusy {
                loginProcessingOverlay
            }
        }
        .alert("Uyarı", isPresented: $vm.showAlert) {
            Button("Tamam", role: .cancel) {}
        } message: {
            Text(vm.alertMessage)
        }
        .alert("SMS kodu", isPresented: $vm.showOtpPrompt) {
            TextField("6 haneli kod", text: $vm.otpCode)
                .keyboardType(.numberPad)
            Button("İptal", role: .cancel) {
                vm.otpCode = ""
            }
            Button("Doğrula") {
                Task {
                    if let user = await vm.confirmPhoneLogin() {
                        providerRawValue = AuthProvider.phone.rawValue
                        userId = user.uid
                        isLoggedIn = true
                    }
                }
            }
        } message: {
            Text("Telefona gelen doğrulama kodunu gir.")
        }
    }

    private var loginRoot: some View {
        ZStack {
            MeshAuroraBackgroundView()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                loginColumnContent
            }
        }
    }

    private var loginColumnContent: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 36)

            Image("LaunchLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 88, height: 88)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .shadow(color: HarmonyPanelChrome.cardShadow(colorScheme: colorScheme), radius: 14, x: 0, y: 8)
                .accessibilityHidden(true)

            VStack(spacing: 8) {
                loginHeroTitle

                Text("Devam etmek için giriş yap.\nTelefon, Apple veya X ile hızlı giriş.")
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 22)

            loginActionsCard

            Spacer(minLength: 24)

            Text("Giriş yaparak KVKK ve Gizlilik Politikasını kabul etmiş olursun.")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 24)
                .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity)
    }

    private var loginHeroTitle: some View {
        Text("Giriş")
            .font(.system(size: 34, weight: .heavy))
            .tracking(-0.8)
            .foregroundStyle(Color(hex: 0xE51245))
            .shadow(color: loginTitleShadowOuter, radius: 0, x: 0, y: 1)
            .shadow(color: loginTitleShadowMid, radius: 4, x: 0, y: 2)
            .shadow(color: loginTitleShadowHighlight, radius: 1, x: 0, y: -0.5)
    }

    private var loginTitleShadowOuter: Color {
        colorScheme == .dark ? Color.black.opacity(0.55) : Color.black.opacity(0.14)
    }

    private var loginTitleShadowMid: Color {
        colorScheme == .dark ? Color.black.opacity(0.25) : Color.black.opacity(0.06)
    }

    private var loginTitleShadowHighlight: Color {
        colorScheme == .dark ? Color.white.opacity(0.1) : Color.clear
    }

    private var loginActionsCard: some View {
        VStack(spacing: 12) {
            phoneInputRow

            Button {
                Task {
                    await vm.startPhoneLogin()
                    if vm.showOtpPrompt {
                        providerRawValue = AuthProvider.phone.rawValue
                    }
                }
            } label: {
                Text("SMS kodu gönder")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .foregroundStyle(.white)
                    .background(HarmonyPanelChrome.primaryCTAFill(cornerRadius: 14, colorScheme: colorScheme))
                    .shadow(color: smsButtonShadow, radius: 12, x: 0, y: 5)
            }
            .buttonStyle(.plain)
            .disabled(vm.isBusy || vm.phoneNationalNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .opacity(
                (vm.isBusy || vm.phoneNationalNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    ? 0.6 : 1.0
            )

            Text("veya")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
                .padding(.vertical, 2)

            SignInWithAppleButton(
                .continue,
                onRequest: { request in
                    vm.prepareAppleSignIn(request)
                },
                onCompletion: { result in
                    Task {
                        if let user = await vm.handleAppleSignIn(result: result) {
                            providerRawValue = AuthProvider.apple.rawValue
                            userId = user.uid
                            isLoggedIn = true
                        }
                    }
                }
            )
            .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
            .environment(\.locale, Locale(identifier: "tr_TR"))
            .frame(maxWidth: .infinity, minHeight: 54, maxHeight: 54)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.primary.opacity(colorScheme == .dark ? 0.22 : 0.1), lineWidth: 1)
            )
            .accessibilityLabel("Apple ile giriş")
            .disabled(vm.isBusy)

            loginTwitterButton
        }
        .padding(20)
        .frame(maxWidth: 440)
        .frame(maxWidth: .infinity)
        .background(
            HarmonyPanelChrome.panelBackdrop(cornerRadius: 26, colorScheme: colorScheme)
                .shadow(color: HarmonyPanelChrome.cardShadow(colorScheme: colorScheme), radius: 18, x: 0, y: 8)
        )
        .padding(.horizontal, 22)
    }

    private var smsButtonShadow: Color {
        Color.black.opacity(colorScheme == .dark ? 0.4 : 0.12)
    }

    private var loginTwitterButton: some View {
        Button {
            Task {
                if let user = await vm.loginWithTwitter() {
                    providerRawValue = AuthProvider.twitter.rawValue
                    userId = user.uid
                    isLoggedIn = true
                }
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.primary)
                Text("X ile giriş")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(
                HarmonyPanelChrome.secondaryTintedButtonBackground(
                    cornerRadius: 14,
                    colorScheme: colorScheme,
                    tint: Color(hex: 0x636366)
                )
            )
        }
        .buttonStyle(.plain)
        .disabled(vm.isBusy)
    }

    private var loginProcessingOverlay: some View {
        ZStack {
            Color.black.opacity(colorScheme == .dark ? 0.45 : 0.22)
                .ignoresSafeArea()

            VStack(spacing: 10) {
                LottieAnimationPlayer(animationName: "loading")
                    .frame(width: 56, height: 56)
                Text("İşleniyor…")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary.opacity(0.85))
            }
            .padding(22)
            .background(
                HarmonyPanelChrome.panelBackdrop(cornerRadius: 18, colorScheme: colorScheme)
                    .shadow(color: HarmonyPanelChrome.cardShadow(colorScheme: colorScheme), radius: 16, x: 0, y: 8)
            )
        }
        .allowsHitTesting(true)
    }

    private var phoneInputRow: some View {
        HStack(spacing: 12) {
            Text("+90")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: 44, alignment: .leading)

            Divider()
                .frame(height: 22)

            TextField(
                "5XX XXX XX XX",
                text: Binding(
                    get: { vm.phoneNationalNumber },
                    set: { vm.updatePhoneInput($0) }
                )
            )
                .font(.system(size: 17, weight: .medium, design: .rounded))
                .keyboardType(.numberPad)
                .textContentType(.telephoneNumber)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .onChange(of: vm.phoneNationalNumber) { _, newValue in
                    vm.updatePhoneInput(newValue)
                }
        }
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, minHeight: 56)
        .background(HarmonyPanelChrome.insetWell(cornerRadius: 14, colorScheme: colorScheme))
    }
}

#if DEBUG
#Preview {
    LoginView(isLoggedIn: .constant(false))
}
#endif

private extension Color {
    init(hex: UInt32, alpha: Double = 1.0) {
        let r = Double((hex & 0xFF0000) >> 16) / 255.0
        let g = Double((hex & 0x00FF00) >> 8) / 255.0
        let b = Double(hex & 0x0000FF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }
}

