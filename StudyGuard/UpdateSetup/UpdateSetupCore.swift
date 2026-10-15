import Foundation
import CryptoKit

struct UpdateSetupFailure: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

// This helper signs one published archive. It cannot publish a different build
// or change the key trusted by installed copies of StudyGuard.
enum PublishedUpdate {
    static let version = "1.6.0"
    static let build = "160"
    static let length = 4_433_237
    static let sha256 = "304d955aacaca081f9ce6b6eb0885686a23422fdea270dd508be4b565c6cb9cc"
    static let publicKey = "Kqe9ZKzDzE54X6wzf1WWeQU7H7dAEbreX50EvJDcHro="
    static let downloadURL = URL(string: "https://github.com/Sumi1124/Focus/releases/download/studyguard-v1.6.0/StudyGuard-1.6.0-macOS-universal.dmg")!

    static func verifyArchive(_ archive: Data) throws {
        let hash = SHA256.hash(data: archive).map { String(format: "%02x", $0) }.joined()
        guard archive.count == length, hash == sha256 else {
            throw UpdateSetupFailure(message: "The download did not match the published StudyGuard update. Please try again.")
        }
    }

    static func verifySignature(_ encoded: String, archive: Data, key: String = publicKey) throws {
        guard let keyData = Data(base64Encoded: key), keyData.count == 32,
              let signature = Data(base64Encoded: encoded), signature.count == 64,
              let publicKey = try? Curve25519.Signing.PublicKey(rawRepresentation: keyData),
              publicKey.isValidSignature(signature, for: archive) else {
            throw UpdateSetupFailure(message: "This key does not match the one trusted by StudyGuard. Open Update Setup on the Mac that created StudyGuard 1.4.")
        }
    }

    static func metadata(archive: Data, signature: String) throws -> String {
        try verifyArchive(archive)
        try verifySignature(signature, archive: archive)
        let fields: [String: Any] = ["version": version, "build": build, "length": length,
                                     "sha256": sha256, "edSignature": signature]
        let data = try JSONSerialization.data(withJSONObject: fields, options: [.sortedKeys])
        return String(decoding: data, as: UTF8.self)
    }

    static func sign(archive: Data, toolURL: URL) throws -> String {
        try verifyArchive(archive)
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("studyguard-update-" + UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        defer { try? FileManager.default.removeItem(at: folder) }
        let archiveURL = folder.appendingPathComponent("StudyGuard-1.6.0.dmg")
        try archive.write(to: archiveURL, options: .atomic)

        let task = Process()
        let output = Pipe()
        task.executableURL = toolURL
        task.arguments = ["--account", "com.studyguard.mac", "-p", archiveURL.path]
        task.standardOutput = output
        // Errors from the signer are not copied or uploaded. The UI explains the
        // Keychain requirement without including credentials or tool output.
        task.standardError = FileHandle.nullDevice
        try task.run()
        let result = output.fileHandleForReading.readDataToEndOfFile()
        task.waitUntilExit()
        guard task.terminationStatus == 0 else {
            throw UpdateSetupFailure(message: "The existing StudyGuard key could not be used. Allow the Keychain request if it appears, and use the Mac that created StudyGuard 1.4.")
        }
        let signature = String(decoding: result, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        return try metadata(archive: archive, signature: signature)
    }
}
