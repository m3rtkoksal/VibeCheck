import Foundation

enum AuthProvider: String, CaseIterable, Identifiable {
    case phone
    case apple
    case twitter

    var id: String { rawValue }

    var title: String {
        switch self {
        case .phone: "Telefon ile giriş"
        case .apple: "Apple ile giriş"
        case .twitter: "X ile giriş"
        }
    }

    var systemImage: String {
        switch self {
        case .phone: "phone.fill"
        case .apple: "apple.logo"
        case .twitter: "bird.fill"
        }
    }
}

