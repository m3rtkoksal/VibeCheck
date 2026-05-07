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
}

