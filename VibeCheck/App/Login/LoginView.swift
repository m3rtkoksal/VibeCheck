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
            ZStack {
                loginBackground.ignoresSafeArea()

                VStack(spacing: 20) {
                    Spacer(minLength: 28)

                    Image("LaunchLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 88, height: 88)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
                        .accessibilityHidden(true)

                    VStack(spacing: 8) {
                        Text("Giriş")
                            .font(.system(size: 34, weight: .bold))
                            .foregroundStyle(.primary)

                        Text("Devam etmek için giriş yap.\nTelefon, Apple veya X ile hızlı giriş.")
                            .font(.system(size: 16))
                            .foregroundStyle(colorScheme == .dark ? .secondary : Color.black.opacity(0.72))
                            .multilineTextAlignment(.center)
                            .lineLimit(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 22)

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
                                .background(Color(hex: 0xFF2D55))
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .disabled(vm.isBusy || vm.phoneNationalNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .opacity((vm.isBusy || vm.phoneNationalNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) ? 0.6 : 1.0)

                        Text("veya")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(colorScheme == .dark ? .secondary : Color.black.opacity(0.65))
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
                        .accessibilityLabel("Apple ile giriş")
                        .disabled(vm.isBusy)

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
                            .background(Color(.systemBackground))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(Color(.separator).opacity(0.35), lineWidth: 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .disabled(vm.isBusy)
                    }
                    .padding(.horizontal, 22)
                    .frame(maxWidth: 440)

                    Spacer()

                    Text("Giriş yaparak KVKK ve Gizlilik Politikasını kabul etmiş olursun.")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(colorScheme == .dark ? .secondary : Color.black.opacity(0.62))
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 12)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .disabled(vm.isBusy)
        .overlay {
            if vm.isBusy {
                ZStack {
                    Color.black.opacity(0.05).ignoresSafeArea()
                    VStack(spacing: 8) {
                        LottieAnimationPlayer(animationName: "loading")
                            .frame(width: 52, height: 52)
                        Text("İşleniyor…")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                        .padding(16)
                        .background(.thinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
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
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, minHeight: 56)
        .background(Color(.systemBackground))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color(.separator).opacity(0.35), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var loginBackground: some View {
        Group {
            if colorScheme == .dark {
                LinearGradient(
                    colors: [Color(hex: 0x121217), Color(hex: 0x191A24), Color(hex: 0x0F1016)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            } else {
                LinearGradient(
                    colors: [Color(hex: 0xFFF6FB), Color(hex: 0xF8F4FF), Color.white],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
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

