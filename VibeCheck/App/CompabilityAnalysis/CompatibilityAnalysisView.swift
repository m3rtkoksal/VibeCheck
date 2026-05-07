import FirebaseFirestore
import Foundation
import SwiftUI
import ContactsUI
import UIKit

struct CompatibilityAnalysisView: View {
    @StateObject private var vm = CompatibilityAnalysisViewModel()
    @AppStorage("profile.privateNote") private var privateNote = ""

    @State private var isMyCodeExpanded = false
    @State private var isPartnerExpanded = true

    @FocusState private var partnerFieldFocused: Bool
    @State private var isSharePresented = false
    @State private var isContactPickerPresented = false
    @Environment(\.colorScheme) private var colorScheme

    private let horizontalInset: CGFloat = 18

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                myCodeCard
                partnerCard
                aiCard

                if let errorText = vm.errorText {
                    Text(errorText)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.red.opacity(0.08))
                        )
                }
            }
            .padding(.horizontal, horizontalInset)
            .padding(.top, 12)
            .padding(.bottom, 110)
        }
        .background(
            LinearGradient(
                colors: [
                    colorScheme == .dark ? Color(hex: 0x12131A) : Color(hex: 0xFFF6F7),
                    colorScheme == .dark ? Color(hex: 0x171A24) : Color(hex: 0xF3F6FF),
                    colorScheme == .dark ? Color(hex: 0x0D0E14) : Color.white,
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        )
        .navigationTitle("Uyum Analizi")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            vm.generateMyCode()
        }
        .scrollDismissesKeyboard(.interactively)
        .simultaneousGesture(TapGesture().onEnded {
            partnerFieldFocused = false
        })
        .navigationDestination(
            isPresented: Binding(
                get: { vm.output != nil },
                set: { isPresented in
                    if !isPresented { vm.output = nil }
                }
            )
        ) {
            if let output = vm.output {
                CompatibilityAnalysisResultView(output: output)
            }
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                partnerFieldFocused = false
                Task { await vm.runCombinedAnalysis(privateNote: privateNote) }
            } label: {
                HStack {
                    Text("AI ile Analiz Et")
                        .font(.headline)
                    Spacer()
                    Image(systemName: "heart.fill")
                        .font(.subheadline)
                }
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 52)
                .background(Color.pink)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
            .disabled(vm.partnerQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || vm.isAnalyzing)
            .opacity((vm.partnerQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || vm.isAnalyzing) ? 0.6 : 1.0)
            .padding(.horizontal, horizontalInset)
            .padding(.top, 10)
            .padding(.bottom, 10)
            .background(.ultraThinMaterial)
        }
        .sheet(isPresented: $isSharePresented) {
            ActivityView(activityItems: [vm.myCode])
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $isContactPickerPresented) {
            ContactPhonePicker { rawPhone in
                let normalized = DiscoverabilityAuthService.normalizedE164Phone(rawPhone)
                vm.partnerQuery = normalized
                isContactPickerPresented = false
            } onCancel: {
                isContactPickerPresented = false
            }
        }
        .overlay {
            if vm.isAnalyzing {
                ZStack {
                    Color.black
                        .opacity(colorScheme == .dark ? 0.42 : 0.28)
                        .ignoresSafeArea()
                    LottieAnimationPlayer(animationName: "loading")
                        .frame(width: 56, height: 56)
                }
            }
        }
    }

    private var myCodeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isMyCodeExpanded.toggle()
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "qrcode")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color(hex: 0xFF2D55))
                        .frame(width: 30, height: 30)
                        .background(Color(hex: 0xFF2D55).opacity(0.12))
                        .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Benim Kodum")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.primary)
                        Text(vm.maskedMyCodePreview)
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    Image(systemName: isMyCodeExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)

            if isMyCodeExpanded {
                QRImage(text: vm.myCode)
                    .frame(maxWidth: .infinity)
                    .frame(height: 210)
                    .padding(.vertical, 4)

                Button {
                    isSharePresented = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "square.and.arrow.up")
                        Text("Vibe Kodumu Paylaş")
                            .fontWeight(.semibold)
                    }
                    .font(.system(size: 15))
                    .foregroundStyle(Color(hex: 0xFF2D55))
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(Color(hex: 0xFF2D55).opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color(hex: 0xFF2D55).opacity(0.55), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(vm.myCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(14)
        .cardStyle()
    }

    private var partnerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isPartnerExpanded.toggle()
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color(hex: 0x2563EB))
                        .frame(width: 30, height: 30)
                        .background(Color(hex: 0x2563EB).opacity(0.12))
                        .clipShape(Circle())

                    Text("Karşı Taraf")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.primary)

                    Spacer()

                    Image(systemName: isPartnerExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)

            if isPartnerExpanded {
                Text("Uyumunu ölçmek istediğin kişiyi seç")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)

                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Vibe Code / telefon / @username", text: $vm.partnerQuery, axis: .vertical)
                        .focused($partnerFieldFocused)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.default)
                        .submitLabel(.done)
                        .onSubmit { partnerFieldFocused = false }
                }
                .padding(.horizontal, 14)
                .frame(minHeight: 48)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                Text("ya da")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)

                Button {
                    partnerFieldFocused = false
                    isContactPickerPresented = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "person.crop.circle.badge.plus")
                        Text("Rehberden Seç")
                            .fontWeight(.semibold)
                    }
                    .font(.system(size: 15))
                    .foregroundStyle(Color(hex: 0xFF2D55))
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(Color(hex: 0xFF2D55).opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color(hex: 0xFF2D55).opacity(0.55), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .cardStyle()
    }

    private var aiCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color(hex: 0x7C3AED))
                    .frame(width: 30, height: 30)
                    .background(Color(hex: 0x7C3AED).opacity(0.12))
                    .clipShape(Circle())

                Text("AI Analizi")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.primary)
            }

            Text("Yapay zeka modelimiz, dijital izlerinizi ve etkileşim tarzlarınızı analiz ederek detaylı bir uyum raporu çıkarır.")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .cardStyle()
    }

}

private extension View {
    func cardStyle() -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(.systemBackground))
                    .shadow(color: Color.black.opacity(0.03), radius: 12, x: 0, y: 6)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color(.separator).opacity(0.22), lineWidth: 1)
            )
    }
}

private extension Color {
    init(hex: UInt32, alpha: Double = 1.0) {
        let r = Double((hex & 0xFF0000) >> 16) / 255.0
        let g = Double((hex & 0x00FF00) >> 8) / 255.0
        let b = Double(hex & 0x0000FF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }
}

private struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

private struct ContactPhonePicker: UIViewControllerRepresentable {
    let onPick: (String) -> Void
    let onCancel: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick, onCancel: onCancel)
    }

    func makeUIViewController(context: Context) -> CNContactPickerViewController {
        let picker = CNContactPickerViewController()
        picker.delegate = context.coordinator
        picker.displayedPropertyKeys = [CNContactPhoneNumbersKey]
        picker.predicateForEnablingContact = NSPredicate(format: "phoneNumbers.@count > 0")
        return picker
    }

    func updateUIViewController(_ uiViewController: CNContactPickerViewController, context: Context) {}

    final class Coordinator: NSObject, CNContactPickerDelegate {
        private let onPick: (String) -> Void
        private let onCancel: () -> Void

        init(onPick: @escaping (String) -> Void, onCancel: @escaping () -> Void) {
            self.onPick = onPick
            self.onCancel = onCancel
        }

        func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
            onCancel()
        }

        func contactPicker(_ picker: CNContactPickerViewController, didSelect contactProperty: CNContactProperty) {
            guard let phone = contactProperty.value as? CNPhoneNumber else { return }
            onPick(phone.stringValue)
        }
    }
}

#Preview {
    NavigationStack {
        CompatibilityAnalysisView()
    }
}
