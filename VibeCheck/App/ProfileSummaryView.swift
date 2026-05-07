import SwiftUI

struct ProfileSummaryView: View {
    /// Snapshot of selections at the time the view is created.
    /// We still refresh from `UserDefaults` on appear to avoid SwiftUI capturing an early empty value.
    private let initialSelections: [String: String]
    @State private var selections: [String: String] = [:]
    @State private var isShowingCompatibility = false
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var discoverabilityVM = SettingsDetailViewModel()

    init(selections: [String: String]) {
        self.initialSelections = selections
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .center, spacing: 18) {
                VStack(alignment: .center, spacing: 10) {
                    Image("LaunchLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 36, height: 36)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                    Text("Senin Profilin")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(.primary)

                    Text("Cevaplarına göre oluşturduğumuz özet.")
                        .font(.system(size: 15))
                        .foregroundStyle(colorScheme == .dark ? .secondary : Color.black.opacity(0.68))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 8)

                if selections.isEmpty {
                    Text("Özet için seçim bulunamadı. Profil ekranına dönüp seçimlerini kaydetmeyi deneyebilirsin.")
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.vertical, 12)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(orderedSelections.enumerated()), id: \.offset) { idx, item in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(item.key.uppercased())
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.7) : Color.secondary)
                                    .kerning(0.4)

                                Text(item.value)
                                    .font(.system(size: 17, weight: .medium))
                                    .foregroundStyle(.primary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)

                            if idx < orderedSelections.count - 1 {
                                Divider()
                                    .padding(.leading, 16)
                            }
                        }
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color(.systemBackground))
                            .shadow(color: Color.black.opacity(0.03), radius: 12, x: 0, y: 6)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color(.separator).opacity(0.2), lineWidth: 1)
                    )
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 110)
        }
        .background(
            Group {
                if colorScheme == .dark {
                    LinearGradient(
                        colors: [Color(hex: 0x121217), Color(hex: 0x191A24), Color(hex: 0x0F1016)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                } else {
                    LinearGradient(
                        colors: [Color(hex: 0xFFF6F7), Color(hex: 0xF3F6FF), Color.white],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            }
            .ignoresSafeArea()
        )
        .navigationTitle("Hazırsın")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // Prefer fresh values; fixes empty summary when destination was constructed early.
            let fresh = ProfileEditorView.selectionsDictionary()
            selections = fresh.isEmpty ? initialSelections : fresh
            discoverabilityVM.syncFromFirebaseUser()
            Task { await discoverabilityVM.syncDiscoverabilityIndex() }
        }
        .navigationDestination(isPresented: $isShowingCompatibility) {
            SelfProfileAnalysisView()
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                isShowingCompatibility = true
            } label: {
                HStack(spacing: 8) {
                    Text("Analiz Et")
                        .font(.headline)
                    Image(systemName: "arrow.forward")
                        .font(.system(size: 14, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.pink)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal)
            .padding(.top, 10)
            .padding(.bottom, 10)
            .background(.ultraThinMaterial)
        }
    }

    private var orderedSelections: [(key: String, value: String)] {
        let normalized = selections.mapValues { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.value.isEmpty }
        var used = Set<String>()
        var result: [(key: String, value: String)] = []

        for category in ProfileCategory.allCases {
            if let value = normalized[category.title] {
                result.append((category.title, value))
                used.insert(category.title)
            }
        }

        let remaining = normalized.keys
            .filter { !used.contains($0) }
            .sorted()
            .map { ($0, normalized[$0] ?? "") }
        result.append(contentsOf: remaining)
        return result
    }
}

#Preview {
    NavigationStack {
        ProfileSummaryView(selections: [
            "Sosyal enerji": "Ambivert",
            "Kıskançlık seviyesi": "Orta"
        ])
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

