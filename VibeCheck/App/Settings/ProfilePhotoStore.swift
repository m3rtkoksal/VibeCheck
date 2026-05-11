import Foundation
import UIKit

enum ProfilePhotoStore {
    static let fileName = "profile_photo.jpg"

    static func url() throws -> URL {
        let dir = try FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return dir.appendingPathComponent(fileName)
    }

    static func load() -> UIImage? {
        do {
            let u = try url()
            guard FileManager.default.fileExists(atPath: u.path) else { return nil }
            let data = try Data(contentsOf: u)
            return UIImage(data: data)
        } catch {
            return nil
        }
    }

    static func save(_ image: UIImage) throws {
        let u = try url()
        let data = image.jpegData(compressionQuality: 0.9) ?? Data()
        try data.write(to: u, options: [.atomic])
    }

    static func remove() throws {
        let u = try url()
        if FileManager.default.fileExists(atPath: u.path) {
            try FileManager.default.removeItem(at: u)
        }
    }

    /// Firebase Storage’a yüklemek için: en uzun kenarı `maxDimension` ile sınırlı JPEG (discoverability’de küçük yüz foto).
    static func jpegDataForPublicDiscoverability(maxDimension: CGFloat = 512, quality: CGFloat = 0.82) -> Data? {
        guard let image = load() else { return nil }
        let w = image.size.width
        let h = image.size.height
        let longest = max(w, h)
        guard longest > 1 else { return nil }
        let scale = min(1, maxDimension / longest)
        guard scale <= 1, scale > 0 else {
            return image.jpegData(compressionQuality: quality)
        }
        let newSize = CGSize(width: floor(w * scale), height: floor(h * scale))
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resized = renderer.image { ctx in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
        return resized.jpegData(compressionQuality: quality)
    }
}

