import SwiftUI

extension Color {
    /// Ana sekme / geçmiş ekranı paleti — `Color(hex:)` dosya çakışmalarını önler.
    init(mtHex: UInt32, alpha: Double = 1.0) {
        let r = Double((mtHex & 0xFF0000) >> 16) / 255.0
        let g = Double((mtHex & 0x00FF00) >> 8) / 255.0
        let b = Double(mtHex & 0x0000FF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }
}
