import SwiftUI
import UIKit

// MARK: - Luminous Soft (DESIGN.md / DESIGN 2.md)

/// Taban pastel yüzeyler — **light**: `background` + `surface-container*`. **dark**: `inverse-surface` tabanlı.
enum AppDesignBackgroundStyle {
    /// Asset katalogda aynı isimlerle görsel eklenirse o kullanılır (yoksa gradient).
    static let lightImageName = "AppBackgroundLight"
    static let darkImageName = "AppBackgroundDark"
}

// MARK: - Gradient (YAML hex)

enum AppDesignBackground {
    static func lightGradient() -> LinearGradient {
        LinearGradient(
            colors: LuminousColor.canvasGradientLight,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static func darkGradient() -> LinearGradient {
        LinearGradient(
            colors: LuminousColor.canvasGradientDark,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static func gradient(colors: [Color]) -> LinearGradient {
        LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

// MARK: - Ekran türüne göre canvas

enum AppScreenCanvasKind: Hashable {
    case onboarding
    case login
    case profileSetup
    case tabProfile
    case tabCompatibility
    case tabHistory
    case tabSettings

    func colors(colorScheme: ColorScheme) -> [Color] {
        switch self {
        case .onboarding:
            return colorScheme == .dark ? LuminousColor.canvasOnboardingDark : LuminousColor.canvasOnboardingLight
        case .login:
            return colorScheme == .dark ? LuminousColor.canvasLoginDark : LuminousColor.canvasLoginLight
        case .profileSetup:
            return colorScheme == .dark ? LuminousColor.canvasSetupDark : LuminousColor.canvasSetupLight
        case .tabProfile:
            return colorScheme == .dark ? LuminousColor.canvasTabProfileDark : LuminousColor.canvasTabProfileLight
        case .tabCompatibility:
            return colorScheme == .dark ? LuminousColor.canvasTabCompatibilityDark : LuminousColor.canvasTabCompatibilityLight
        case .tabHistory:
            return colorScheme == .dark ? LuminousColor.canvasTabHistoryDark : LuminousColor.canvasTabHistoryLight
        case .tabSettings:
            return colorScheme == .dark ? LuminousColor.canvasTabSettingsDark : LuminousColor.canvasTabSettingsLight
        }
    }
}

struct AppScreenCanvasBackground: View {
    let kind: AppScreenCanvasKind
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        AppDesignBackground.gradient(colors: kind.colors(colorScheme: colorScheme))
            .ignoresSafeArea()
    }
}

/// Tüm uygulama kabuğu için ortak arka plan (görsel veya Luminous Soft gradient).
struct AppDesignBackgroundView: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Group {
            if let ui = resolvedUIImage {
                Image(uiImage: ui)
                    .resizable()
                    .scaledToFill()
            } else {
                MeshAuroraBackgroundView()
            }
        }
        .ignoresSafeArea()
    }

    private var resolvedUIImage: UIImage? {
        let name = colorScheme == .dark ? AppDesignBackgroundStyle.darkImageName : AppDesignBackgroundStyle.lightImageName
        guard let image = UIImage(named: name), image.size.width > 2, image.size.height > 2 else { return nil }
        return image
    }
}

/// Kök `ContentView` ve tüm tam ekran akışlar için sarın; altındaki ekranların kendi düz `pageBackground` katmanını
/// **şeffaf** tutması gerekir (`Color.clear`).
struct AppBaseView<Content: View>: View {
    @ViewBuilder var content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        ZStack {
            AppDesignBackgroundView()
            content()
        }
    }
}
