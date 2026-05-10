import SwiftUI

struct ThemeSelectionView: View {
    /// 0: sistem, 1: açık, 2: koyu
    @AppStorage("app.colorSchemePreference") private var colorSchemePreference = 0
    @State private var pendingSelection: Int = 0

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    private var palette: ThemeSelectionPalette {
        colorScheme == .dark ? .dark : .light
    }

    var body: some View {
        ZStack {
            palette.pageBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                appearanceTopBar

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(
                            """
                            Uygulama temasını seçin. "Sistem", cihazınızın mevcut görünüm ayarına otomatik olarak uyum sağlar.
                            """
                        )
                        .font(.system(size: 15))
                        .foregroundStyle(palette.onSurfaceVariant)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 8)

                        themeOptionsCard

                        Spacer(minLength: 32)
                    }
                    .frame(maxWidth: 520)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 24)
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            applyDock
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { pendingSelection = colorSchemePreference }
    }

    // MARK: - Üst çubuk

    private var appearanceTopBar: some View {
        VStack(spacing: 0) {
            ZStack {
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.backward")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(palette.onSurfaceVariant)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    Spacer(minLength: 0)

                    appearanceTopBarMenu
                }

                Text("Görünüm")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(palette.topBarTitle)
                    .lineLimit(1)
            }
            .padding(.horizontal, 20)
            .frame(height: 56)

            Rectangle()
                .fill(palette.topBarDivider)
                .frame(height: 1)
        }
        .frame(maxWidth: .infinity)
        .background(.regularMaterial.opacity(colorScheme == .dark ? 0.88 : 0.92))
    }

    private var appearanceTopBarMenu: some View {
        Menu {
            Button(appVersionCompact) {}
                .disabled(true)
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(palette.onSurfaceVariant)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
    }

    // MARK: - Tema kartı

    private var themeOptionsCard: some View {
        VStack(spacing: 0) {
            themeOptionRow(title: "Açık", value: 1, symbol: "sun.max.fill", showDivider: true)
            themeOptionRow(title: "Koyu", value: 2, symbol: "moon.fill", showDivider: true)
            themeOptionRow(title: "Sistem", value: 0, symbol: "circle.lefthalf.filled", showDivider: false)
        }
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(palette.cardFill)
                .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.35 : 0.04), radius: 20, x: 0, y: 10)
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func themeOptionRow(
        title: String,
        value: Int,
        symbol: String,
        showDivider: Bool
    ) -> some View {
        Button {
            pendingSelection = value
        } label: {
            VStack(spacing: 0) {
                HStack(spacing: 16) {
                    Image(systemName: symbol)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(palette.onSurface)
                        .frame(width: 40, height: 40)
                        .background(
                            Circle()
                                .fill(palette.iconWellFill)
                        )

                    Text(title)
                        .font(.system(size: 17))
                        .foregroundStyle(palette.onSurface)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(
                            pendingSelection == value ? Color(hex: 0xBA0034) : Color.clear
                        )
                        .accessibilityHidden(true)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 24)
                .contentShape(Rectangle())

                if showDivider {
                    Rectangle()
                        .fill(palette.rowDivider)
                        .frame(height: 1)
                }
            }
        }
        .buttonStyle(ThemeOptionRowButtonStyle(
            pressedFill: colorScheme == .dark
                ? Color.white.opacity(0.06)
                : Color(hex: 0xF4F3F8)
        ))
        .accessibilityAddTraits(pendingSelection == value ? .isSelected : [])
    }

    // MARK: - Alt uygula

    private var applyDock: some View {
        VStack(spacing: 0) {
            Button {
                colorSchemePreference = pendingSelection
                dismiss()
            } label: {
                Text("Değişiklikleri Uygula")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color(hex: 0xBA0034))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: Color.black.opacity(0.12), radius: 8, x: 0, y: 4)
            }
            .buttonStyle(ThemeApplyButtonStyle())
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity)
        .background(.regularMaterial.opacity(colorScheme == .dark ? 0.92 : 0.94))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(palette.topBarDivider)
                .frame(height: 1)
        }
    }

    private var appVersionCompact: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        return "Versiyon \(version)"
    }
}

// MARK: - Palet

private enum ThemeSelectionPalette {
    case light
    case dark

    var pageBackground: Color {
        switch self {
        case .light: return Color(hex: 0xFAF9FE)
        case .dark: return Color(hex: 0x131315)
        }
    }

    var cardFill: Color {
        switch self {
        case .light: return Color(hex: 0xFFFFFF)
        case .dark: return Color(hex: 0x1E1E23)
        }
    }

    var iconWellFill: Color {
        switch self {
        case .light: return Color(hex: 0xEEEDF3)
        case .dark: return Color(hex: 0x2A2A30)
        }
    }

    var onSurface: Color {
        switch self {
        case .light: return Color(hex: 0x1A1B1F)
        case .dark: return Color(hex: 0xE5E1E4)
        }
    }

    var onSurfaceVariant: Color {
        switch self {
        case .light: return Color(hex: 0x5D3F40)
        case .dark: return Color(hex: 0xCAB8B9)
        }
    }

    var topBarTitle: Color {
        switch self {
        case .light: return Color(hex: 0x111827)
        case .dark: return Color(hex: 0xF9FAFB)
        }
    }

    var topBarDivider: Color {
        switch self {
        case .light: return Color(hex: 0xE9E7ED)
        case .dark: return Color.white.opacity(0.08)
        }
    }

    var rowDivider: Color {
        switch self {
        case .light: return Color(hex: 0xE3E2E7)
        case .dark: return Color.white.opacity(0.1)
        }
    }
}

// MARK: - Basınç stilleri

private struct ThemeOptionRowButtonStyle: ButtonStyle {
    var pressedFill: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                configuration.isPressed ? pressedFill : Color.clear
            )
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

private struct ThemeApplyButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.18), value: configuration.isPressed)
    }
}

#Preview {
    NavigationStack {
        ThemeSelectionView()
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
