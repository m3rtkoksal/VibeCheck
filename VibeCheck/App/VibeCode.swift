import Foundation

enum VibeCode {
    private static let prefix = "vbc1."

    static func encode(_ snapshot: ProfileSnapshot) throws -> String {
        let data = try JSONEncoder().encode(snapshot)
        return prefix + base64URLEncode(data)
    }

    static func decode(_ code: String) throws -> ProfileSnapshot {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix(prefix) else {
            throw VibeCodeError.invalidPrefix
        }
        let b64url = String(trimmed.dropFirst(prefix.count))
        let data = try base64URLDecode(b64url)
        return try JSONDecoder().decode(ProfileSnapshot.self, from: data)
    }

    private static func base64URLEncode(_ data: Data) -> String {
        let b64 = data.base64EncodedString()
        return b64
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private static func base64URLDecode(_ string: String) throws -> Data {
        var b64 = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let pad = (4 - (b64.count % 4)) % 4
        if pad > 0 { b64 += String(repeating: "=", count: pad) }
        guard let data = Data(base64Encoded: b64) else {
            throw VibeCodeError.invalidBase64
        }
        return data
    }
}

enum VibeCodeError: Error {
    case invalidPrefix
    case invalidBase64
}

