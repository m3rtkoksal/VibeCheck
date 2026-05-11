import SwiftUI

extension Color {
    /// Bu ekrana özel hex init; projedeki diğer dosyalarla `Color(hex:)` çakışmasını önler.
    init(crHex: UInt32, alpha: Double = 1.0) {
        let r = Double((crHex & 0xFF0000) >> 16) / 255.0
        let g = Double((crHex & 0x00FF00) >> 8) / 255.0
        let b = Double(crHex & 0x0000FF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }
}
