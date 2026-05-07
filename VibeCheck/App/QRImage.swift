import CoreImage.CIFilterBuiltins
import SwiftUI

struct QRImage: View {
    private let context = CIContext()
    private let filter = CIFilter.qrCodeGenerator()

    let text: String

    var body: some View {
        if let image = makeImage(from: text) {
            Image(uiImage: image)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
        } else {
            Color.secondary.opacity(0.15)
                .overlay {
                    Text("QR üretilemedi")
                        .foregroundStyle(.secondary)
                }
        }
    }

    private func makeImage(from text: String) -> UIImage? {
        filter.setValue(Data(text.utf8), forKey: "inputMessage")
        guard let output = filter.outputImage else { return nil }

        // scale up for crisp QR
        let transform = CGAffineTransform(scaleX: 12, y: 12)
        let scaled = output.transformed(by: transform)

        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}

