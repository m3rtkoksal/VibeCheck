import SwiftUI

struct ThemeSelectionView: View {
    /// 0: sistem, 1: açık, 2: koyu
    @AppStorage("app.colorSchemePreference") private var colorSchemePreference = 0
    @State private var pendingSelection: Int = 0

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Görünüm")
                        .font(.system(size: 28, weight: .bold))
                        .padding(.top, 8)

                    Text("VibeCheck’in cihazında nasıl görüneceğini özelleştir.")
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)

                    Text("Tema")
                        .font(.system(size: 12, weight: .semibold))
                        .textCase(.uppercase)
                        .tracking(0.8)
                        .foregroundStyle(.secondary)
                        .padding(.top, 8)

                    VStack(spacing: 0) {
                        themeRow(title: "Açık", value: 1)
                        dividerInset
                        themeRow(title: "Koyu", value: 2)
                        dividerInset
                        themeRow(title: "Sistem", value: 0)
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(Color(.systemBackground))
                            .shadow(color: Color.black.opacity(0.04), radius: 16, x: 0, y: 8)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(Color(.separator).opacity(0.25), lineWidth: 1)
                    )

                    Spacer(minLength: 120)
                }
                .padding(.horizontal, 20)
                .padding(.top, 64)
            }

            applyBar
        }
        .navigationBarBackButtonHidden(true)
        .overlay(alignment: .top) { topBar }
        .onAppear { pendingSelection = colorSchemePreference }
    }

    private var topBar: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea(edges: .top)
                .frame(height: 64)
                .overlay(Divider().opacity(0.35), alignment: .bottom)

            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .frame(width: 36, height: 36)
                        .contentShape(Rectangle())
                        .foregroundStyle(Color(hex: 0xFF2D55))
                }

                Spacer()
            }
            .padding(.horizontal, 12)
            .frame(height: 64)
        }
    }

    private func themeRow(title: String, value: Int) -> some View {
        Button {
            pendingSelection = value
        } label: {
            HStack(spacing: 12) {
                Text(title)
                    .font(.system(size: 17, weight: .regular))
                    .foregroundStyle(.primary)

                Spacer()

                if pendingSelection == value {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color(hex: 0xFF2D55))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var dividerInset: some View {
        Divider()
            .padding(.leading, 16)
            .opacity(0.35)
    }

    private var applyBar: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea(edges: .bottom)

            Button {
                colorSchemePreference = pendingSelection
                dismiss()
            } label: {
                Text("Değişiklikleri Uygula")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .background(Color(hex: 0xFF2D55))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: Color.black.opacity(0.06), radius: 16, x: 0, y: 10)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .frame(height: 88)
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

