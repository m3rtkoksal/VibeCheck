import SwiftUI

/// Profil soruları ve özel not. Kurulum akışında (`setupMode`) tamamlanınca özete geçiş butonu gösterilir;
/// ana uygulama tab’ında sadece düzenleme.
struct ProfileEditorView: View {
    private let categories: [ProfileCategory] = ProfileCategory.allCases
    @State private var refreshToken = UUID()
    @AppStorage("profile.privateNote") private var privateNote = ""
    @State private var selectedCategory: ProfileCategory?
    @State private var showPrivateNote = false
    @State private var showInsightSummary = false
    @Environment(\.colorScheme) private var colorScheme

    var setupMode: Bool
    @Binding var showSummary: Bool

    init(setupMode: Bool = false, showSummary: Binding<Bool> = .constant(false)) {
        self.setupMode = setupMode
        self._showSummary = showSummary
    }

    var body: some View {
        List {
            if !setupMode {
                Section {
                    Button {
                        showInsightSummary = true
                    } label: {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color.pink.opacity(0.12))
                                Image(systemName: "sparkles")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(Color.pink)
                            }
                            .frame(width: 34, height: 34)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Karakter özetin")
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundStyle(.primary)

                                Text("AI tabanlı kişilik içgörülerin")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 8) {
                                if let badge = insightBadge {
                                    Text(badge.title)
                                        .font(.system(size: 11, weight: .semibold))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(badge.background)
                                        .foregroundStyle(badge.foreground)
                                        .clipShape(Capsule())
                                }

                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .padding(.vertical, 14)
                        .padding(.horizontal, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Color(.systemBackground))
                                .shadow(color: Color.black.opacity(0.03), radius: 12, x: 0, y: 6)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(Color(.separator).opacity(0.25), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                    .listRowBackground(Color.clear)
                } header: {
                    Text("AI Özet")
                        .textCase(nil)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Color(.label))
                }
            }

            Section {
                ForEach(categories) { category in
                    Button {
                        selectedCategory = category
                    } label: {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(category.title)
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundStyle(.primary)

                                Text(selectedValue(for: category) ?? "Seç")
                                    .font(.system(size: 15))
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 14)
                        .padding(.horizontal, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Color(.systemBackground))
                                .shadow(color: Color.black.opacity(0.03), radius: 12, x: 0, y: 6)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(Color(.separator).opacity(0.25), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                    .listRowBackground(Color.clear)
                }
            } header: {
                Text("Soru ve Cevaplar")
                    .textCase(nil)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Color(.label))
            }

            Section {
                Button {
                    showPrivateNote = true
                } label: {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Kendim hakkında (özel)")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(.primary)

                            Text(privateNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Boş" : "Dolu")
                                .font(.system(size: 15))
                                .foregroundStyle(.secondary)

                            Text("Bu metin diğer üyelere gösterilmez. Gelişmiş analizde sadece senin için kullanılır.")
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                                .padding(.top, 4)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 14)
                    .padding(.horizontal, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color(.systemBackground))
                            .shadow(color: Color.black.opacity(0.03), radius: 12, x: 0, y: 6)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color(.separator).opacity(0.25), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                .listRowBackground(Color.clear)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(profileGradient.ignoresSafeArea())
        .navigationTitle(setupMode ? "Profilini tamamla" : "Profil")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $selectedCategory) { category in
            AnswerView(
                category: category,
                onContinue: { current in
                    goToNextQuestion(after: current)
                }
            )
        }
        .navigationDestination(isPresented: $showPrivateNote) {
            PrivateNoteView(note: $privateNote)
        }
        .navigationDestination(isPresented: $showInsightSummary) {
            ProfileCharacterInsightView()
        }
        .safeAreaInset(edge: .bottom) {
            if setupMode && isCompleteProfile {
                Button {
                    showSummary = true
                } label: {
                    Text("Devam")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.pink)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal)
                .padding(.top, 10)
                .padding(.bottom, 10)
                .background(.ultraThinMaterial)
            }
        }
        .id(refreshToken)
        .onAppear {
            refreshToken = UUID()
        }
    }

    private func goToNextQuestion(after current: ProfileCategory) -> Bool {
        guard let currentIndex = categories.firstIndex(of: current) else { return false }
        let nextIndex = categories.index(after: currentIndex)
        guard nextIndex < categories.endIndex else {
            // Son çoktan seçmeli sorudan sonra akışı metin sorusuna taşı.
            showPrivateNote = true
            return true
        }
        selectedCategory = categories[nextIndex]
        return true
    }

    private var profileGradient: some View {
        LinearGradient(
            colors: [
                colorScheme == .dark ? Color(hex: 0x12131A) : Color(hex: 0xFFF6F7),
                colorScheme == .dark ? Color(hex: 0x171A24) : Color(hex: 0xF3F6FF),
                colorScheme == .dark ? Color(hex: 0x0D0E14) : Color(hex: 0xFFFFFF),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var isCompleteProfile: Bool {
        let allChoicesSelected = categories.allSatisfy { selectedValue(for: $0) != nil }
        let noteFilled = !privateNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return allChoicesSelected && noteFilled
    }

    private var insightBadge: (title: String, foreground: Color, background: Color)? {
        switch SelfProfileInsightStore.profileTabBadge(isProfileComplete: isCompleteProfile) {
        case .none:
            return nil
        case .missingAnalysis:
            return (
                "Eksik",
                Color.secondary,
                Color(.secondarySystemFill)
            )
        case .needsRefresh:
            return (
                "Güncelle",
                Color.orange,
                Color.orange.opacity(0.12)
            )
        }
    }

    private func selectedValue(for category: ProfileCategory) -> String? {
        let key = "profile.category.\(category.id)"
        let value = UserDefaults.standard.string(forKey: key) ?? ""
        return value.isEmpty ? nil : value
    }

    /// Profil özet ekranı ve sunucu tarafı için `soru başlığı → seçim` sözlüğü.
    static func selectionsDictionary() -> [String: String] {
        var result: [String: String] = [:]
        for category in ProfileCategory.allCases {
            let key = "profile.category.\(category.id)"
            let value = UserDefaults.standard.string(forKey: key) ?? ""
            if !value.isEmpty {
                result[category.title] = value
            }
        }
        return result
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

#Preview("Setup") {
    NavigationStack {
        ProfileEditorView(setupMode: true, showSummary: .constant(false))
    }
}

#Preview("Tab") {
    NavigationStack {
        ProfileEditorView()
    }
}
