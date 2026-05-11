import SwiftUI
import PhotosUI

/// Bulunabilirlik: telefon (SMS OTP), X (Firebase OAuth).
struct SettingsDetailView: View {
    /// 0: sistem, 1: açık, 2: koyu
    @AppStorage("app.colorSchemePreference") private var colorSchemePreference = 0

    @State private var alertMessage = ""
    @State private var showAlert = false
    @State private var showThemePicker = false

    @Environment(\.dismiss) private var dismiss
    @State private var showPhotoSheet = false
    @State private var showCameraPicker = false
    @State private var showPhotoLibraryPicker = false
    @State private var photoPickerItem: PhotosPickerItem?
    @State private var profileUIImage: UIImage?
    @AppStorage("profile.photoSaved") private var photoSaved = false

    @StateObject private var vm = SettingsDetailViewModel()

    var body: some View {
        ZStack {
            ZStack(alignment: .top) {
                ScrollView {
                    VStack(spacing: 24) {
                        profilePictureSection

                        VStack(alignment: .leading, spacing: 12) {
                            Text("BAĞLI HESAPLAR")
                                .font(.system(size: 12, weight: .semibold))
                                .textCase(.uppercase)
                                .tracking(0.8)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 20)

                            VStack(spacing: 0) {
                                linkedAccountRow(
                                    icon: "xmark",
                                    iconBackground: .black,
                                    iconForeground: .white,
                                    title: "Twitter (X)",
                                    subtitle: xRowSubtitle,
                                    isConnected: vm.xVerified
                                ) {
                                    vm.showAlert = false
                                    vm.alertMessage = ""
                                    // open sheet
                                    showLinkedXSheet = true
                                }

                                Divider().opacity(0.35).padding(.leading, 16 + 40 + 16)

                                linkedAccountRow(
                                    icon: "phone.fill",
                                    iconBackground: .green,
                                    iconForeground: .white,
                                    title: "Telefon Numarası",
                                    subtitle: phoneRowSubtitle,
                                    isConnected: vm.phoneVerified
                                ) {
                                    showLinkedPhoneSheet = true
                                }
                            }
                            .background(
                                RoundedRectangle(cornerRadius: 24, style: .continuous)
                                    .fill(Color(.systemBackground))
                                    .shadow(color: Color.black.opacity(0.04), radius: 16, x: 0, y: 8)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 24, style: .continuous)
                                    .stroke(Color(.separator).opacity(0.20), lineWidth: 1)
                            )
                            .padding(.horizontal, 20)
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            Text("GÖRÜNEN AD")
                                .font(.system(size: 12, weight: .semibold))
                                .textCase(.uppercase)
                                .tracking(0.8)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 20)

                            VStack(alignment: .leading, spacing: 8) {
                                TextField("İsim Soyad", text: $vm.fullName)
                                    .textInputAutocapitalization(.words)
                                    .autocorrectionDisabled(true)
                                    .font(.system(size: 16, weight: .semibold))

                                Text("Geçmiş listelerinde kullanıcı adın yerine bu isim görünür.")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(16)
                            .background(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .fill(Color(.systemBackground))
                                    .shadow(color: Color.black.opacity(0.04), radius: 12, x: 0, y: 6)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .stroke(Color(.separator).opacity(0.20), lineWidth: 1)
                            )
                            .padding(.horizontal, 20)
                        }

                        Spacer(minLength: 96)
                    }
                    .padding(.top, 88)
                }

                editProfileTopBar

                saveBar
            }
            .navigationBarBackButtonHidden(true)
            .disabled(vm.isBusy)
            .overlay { busyOverlay }
        }
        .task {
            vm.syncFromFirebaseUser()
            await vm.syncDiscoverabilityIndex()
        }
        .onAppear {
            vm.syncFromFirebaseUser()
            Task { await vm.syncDiscoverabilityIndex() }
        }
        .onChange(of: vm.phoneDiscoverable) { _, _ in
            Task { await vm.syncDiscoverabilityIndex() }
        }
        .onChange(of: vm.xDiscoverable) { _, _ in
            Task { await vm.syncDiscoverabilityIndex() }
        }
        .onChange(of: vm.fullName) { _, _ in
            Task { await vm.syncDiscoverabilityIndex() }
        }
        .confirmationDialog("Tema Seçimi", isPresented: $showThemePicker, titleVisibility: .visible) {
            Button("Sistem") { colorSchemePreference = 0 }
            Button("Açık") { colorSchemePreference = 1 }
            Button("Koyu") { colorSchemePreference = 2 }
            Button("İptal", role: .cancel) {}
        } message: {
            Text("Uygulama temasını seç.")
        }
        .alert("Uyarı", isPresented: $showAlert) {
            Button("Tamam", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
        .alert("SMS kodu", isPresented: $vm.showOtpPrompt) {
            TextField("6 haneli kod", text: $vm.otpCode)
                .keyboardType(.numberPad)
            Button("İptal", role: .cancel) { vm.otpCode = "" }
            Button("Doğrula") { Task { await vm.verifyPhoneOtp() } }
        } message: {
            Text("Telefona gelen doğrulama kodunu gir.")
        }
        .sheet(isPresented: $showLinkedXSheet) {
            NavigationStack {
                Form {
                    xSection
                }
                .navigationTitle("Twitter (X)")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Kapat") { showLinkedXSheet = false }
                    }
                }
            }
        }
        .sheet(isPresented: $showLinkedPhoneSheet) {
            NavigationStack {
                Form {
                    phoneSection
                }
                .navigationTitle("Telefon")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Kapat") { showLinkedPhoneSheet = false }
                    }
                }
            }
        }
        .sheet(isPresented: $showPhotoSheet) {
            profilePhotoSheet
                .presentationDetents([.height(320)])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showCameraPicker) {
            ImagePicker(sourceType: .camera) { image in
                profileUIImage = image
            }
            .ignoresSafeArea()
        }
        .photosPicker(
            isPresented: $showPhotoLibraryPicker,
            selection: $photoPickerItem,
            matching: .images
        )
        .onChange(of: photoPickerItem) { _, newItem in
            guard let newItem else { return }
            Task {
                do {
                    if let data = try await newItem.loadTransferable(type: Data.self),
                       let uiImage = UIImage(data: data) {
                        await MainActor.run { profileUIImage = uiImage }
                    }
                } catch {
                    await MainActor.run {
                        alertMessage = error.localizedDescription
                        showAlert = true
                    }
                }
            }
        }
        .onAppear {
            if profileUIImage == nil, photoSaved {
                profileUIImage = ProfilePhotoStore.load()
            }
        }
    }

    @ViewBuilder
    private var phoneSection: some View {
        Section {
            if vm.phoneVerified {
                HStack {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                    Text(vm.phoneNumber.isEmpty ? "Doğrulandı" : vm.phoneNumber)
                }
                Button("Telefon doğrulamasını kaldır", role: .destructive) {
                    Task { await vm.unlinkPhone() }
                }
            } else {
                TextField("Örn. +90 5xx xxx xx xx", text: $vm.phoneNumber)
                    .keyboardType(.phonePad)
                    .textContentType(.telephoneNumber)

                Button("SMS kodu gönder") {
                    Task { await vm.sendSms() }
                }
                .disabled(vm.trimmed(vm.phoneNumber).isEmpty)
            }

            Toggle(
                "Bu telefon numarasıyla bulunabileyim",
                isOn: $vm.phoneDiscoverable
            )
            .disabled(!vm.phoneVerified || vm.trimmed(vm.phoneNumber).isEmpty)
        } header: {
            Text("Telefon")
        } footer: {
            Text(
                vm.phoneVerified
                    ? "Numara Firebase ile doğrulandı. İstersen bulunabilirliği aç."
                    : "SMS ile numaranı doğrula; sadece doğrulanmış numara ile aramaya izin ver."
            )
            .font(.footnote)
        }
        .onChange(of: vm.phoneNumber) { _, newValue in
            if vm.trimmed(newValue).isEmpty {
                vm.phoneDiscoverable = false
            }
        }
    }

    @ViewBuilder
    private var xSection: some View {
        Section {
            if vm.xVerified {
                HStack {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                    Text(vm.xUsername.isEmpty ? "X doğrulandı" : "@\(vm.xUsername)")
                }
                Button("X bağlantısını kaldır", role: .destructive) {
                    Task { await vm.unlinkTwitter() }
                }
            } else {
                Button("X (Twitter) ile doğrula") {
                    Task { await vm.linkTwitter() }
                }
            }

            Toggle(
                "Bu X hesabıyla bulunabileyim",
                isOn: $vm.xDiscoverable
            )
            .disabled(!vm.xVerified || vm.trimmed(vm.xUsername).isEmpty)
        } header: {
            Text("X (Twitter)")
        }
        .onChange(of: vm.xUsername) { _, newValue in
            if vm.trimmed(newValue).isEmpty {
                vm.xDiscoverable = false
            }
        }
    }

    private var footerSection: some View {
        Section {
            Text(
                "Doğrulanmayan bilgilerle arama sunmayız; böylece sahte @ veya numara taşınmaz."
            )
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
    }

    private func trimmed(_ s: String) -> String {
        s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var editProfileTopBar: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea(edges: .top)
                .frame(height: 64)
                .overlay(
                    Divider()
                        .opacity(0.35),
                    alignment: .bottom
                )

            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .frame(width: 36, height: 36)
                        .background(Color(.systemBackground).opacity(0.001))
                        .contentShape(Rectangle())
                        .foregroundStyle(Color(hex: 0xFF2D55))
                }

                Spacer()

                Text("Profili Düzenle")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.primary)

                Spacer()

                Color.clear.frame(width: 36, height: 36)
            }
            .padding(.horizontal, 12)
            .frame(height: 64)
        }
    }

    private var profilePictureSection: some View {
        VStack(spacing: 12) {
            Button {
                showPhotoSheet = true
            } label: {
                ZStack(alignment: .bottomTrailing) {
                    avatarViewLarge

                    ZStack {
                        Circle().fill(Color(hex: 0xFF2D55))
                        Image(systemName: "camera.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .frame(width: 34, height: 34)
                    .overlay(Circle().stroke(.white, lineWidth: 2))
                    .offset(x: -4, y: -4)
                }
            }

            Button {
                showPhotoSheet = true
            } label: {
                Text("Fotoğrafı Değiştir")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color(hex: 0xFF2D55))
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 24)
    }

    private var profilePhotoSheet: some View {
        VStack(spacing: 12) {
            Capsule()
                .fill(Color.secondary.opacity(0.25))
                .frame(width: 40, height: 5)
                .padding(.top, 8)

            Text("Profil Fotoğrafını Değiştir")
                .font(.system(size: 17, weight: .semibold))
                .padding(.top, 4)

            VStack(spacing: 0) {
                sheetRow(icon: "camera.fill", title: "Fotoğraf Çek") {
                    showPhotoSheet = false
                    if UIImagePickerController.isSourceTypeAvailable(.camera) {
                        showCameraPicker = true
                    } else {
                        alertMessage = "Bu cihazda kamera kullanılamıyor."
                        showAlert = true
                    }
                }
                Divider().opacity(0.35).padding(.leading, 16 + 24 + 12)

                sheetRow(icon: "photo.on.rectangle.angled", title: "Galeriden Seç") {
                    showPhotoSheet = false
                    showPhotoLibraryPicker = true
                }
                Divider().opacity(0.35).padding(.leading, 16 + 24 + 12)

                sheetRow(icon: "trash.fill", title: "Mevcut Fotoğrafı Kaldır", titleColor: .red) {
                    profileUIImage = nil
                    do {
                        try ProfilePhotoStore.remove()
                        photoSaved = false
                    } catch {
                        alertMessage = error.localizedDescription
                        showAlert = true
                    }
                    showPhotoSheet = false
                    Task { await vm.syncDiscoverabilityIndex() }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
            )

            Button("İptal") {
                showPhotoSheet = false
            }
            .font(.system(size: 17, weight: .semibold))
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
            )

            Spacer(minLength: 8)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
        .background(Color(.systemBackground))
    }

    private func sheetRow(
        icon: String,
        title: String,
        titleColor: Color = .primary,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(titleColor == .red ? .red : Color(hex: 0xFF2D55))
                    .frame(width: 24)

                Text(title)
                    .font(.system(size: 17, weight: .regular))
                    .foregroundStyle(titleColor)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var avatarViewLarge: some View {
        let size: CGFloat = 128
        return ZStack {
            Circle()
                .fill(Color(.secondarySystemBackground))
            if let profileUIImage {
                Image(uiImage: profileUIImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else {
                Image(systemName: "person.fill")
                    .font(.system(size: 48, weight: .medium))
                    .foregroundStyle(.secondary.opacity(0.55))
                    .symbolRenderingMode(.hierarchical)
            }
        }
        .frame(width: size, height: size)
        .overlay(
            Circle().stroke(Color.white, lineWidth: 4)
        )
        .shadow(color: Color.black.opacity(0.06), radius: 16, x: 0, y: 10)
        .padding(.bottom, 4)
    }

    private func linkedAccountRow(
        icon: String,
        iconBackground: Color,
        iconForeground: Color,
        title: String,
        subtitle: String,
        isConnected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    Circle().fill(iconBackground)
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(iconForeground)
                }
                .frame(width: 40, height: 40)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(title)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.primary)

                        Text(isConnected ? "Bağlı" : "Bağlı Değil")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(isConnected ? Color.green : .secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(
                                        isConnected
                                            ? Color.green.opacity(0.12)
                                            : Color(.tertiarySystemFill)
                                    )
                            )
                    }
                    Text(subtitle)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var busyOverlay: some View {
        Group {
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
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
        }
    }

    private var themeLabel: String {
        switch colorSchemePreference {
        case 1: return "Açık"
        case 2: return "Koyu"
        default: return "Sistem"
        }
    }

    private var xRowSubtitle: String {
        if vm.xVerified, !trimmed(vm.xUsername).isEmpty {
            return "@\(trimmed(vm.xUsername))"
        }
        return "Bağlı değil"
    }

    private var phoneRowSubtitle: String {
        if vm.phoneVerified, !trimmed(vm.phoneNumber).isEmpty {
            return trimmed(vm.phoneNumber)
        }
        return "Bağlı değil"
    }

    private var saveBar: some View {
        VStack {
            Spacer()
            ZStack {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .ignoresSafeArea(edges: .bottom)

                Button {
                    alertMessage = "Kaydedildi."
                    showAlert = true
                    if let profileUIImage {
                        do {
                            try ProfilePhotoStore.save(profileUIImage)
                            photoSaved = true
                        } catch {
                            alertMessage = error.localizedDescription
                            showAlert = true
                        }
                    }
                    Task { await vm.syncDiscoverabilityIndex() }
                    dismiss()
                } label: {
                    Text("Kaydet")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(Color(hex: 0xFF2D55))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .shadow(color: Color.black.opacity(0.06), radius: 16, x: 0, y: 10)
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 12)
            }
            .frame(height: 88)
        }
        .allowsHitTesting(true)
    }

    @State private var showLinkedPhoneSheet = false
    @State private var showLinkedXSheet = false
}

#if DEBUG
// Backwards-compatibility for any old references.
typealias DiscoverabilitySettingsView = SettingsDetailView
#endif

#if DEBUG
#Preview {
    NavigationStack {
        SettingsDetailView()
    }
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

private struct ImagePicker: UIViewControllerRepresentable {
    let sourceType: UIImagePickerController.SourceType
    let onImagePicked: (UIImage) -> Void

    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        picker.allowsEditing = true
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        private let parent: ImagePicker

        init(parent: ImagePicker) {
            self.parent = parent
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            let edited = info[.editedImage] as? UIImage
            let original = info[.originalImage] as? UIImage
            if let image = edited ?? original {
                parent.onImagePicked(image)
            }
            parent.dismiss()
        }
    }
}
