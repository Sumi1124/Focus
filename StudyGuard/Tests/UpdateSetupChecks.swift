import Foundation
import CryptoKit

@main
struct UpdateSetupChecks {
    static func main() throws {
        guard CommandLine.arguments.count == 3 else { fatalError("Pass the published 1.6.0 and signed 1.4.0 archives") }
        let archive = try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1]))
        try PublishedUpdate.verifyArchive(archive)
        let original = try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[2]))
        let originalSignature = "c7QjL0llMMT58uYEqNKa6HGU1Vj9vgB8ysl08O9vNPleSO3fkISUnWwVcGnnGW9hGgrCUQ7xxnIp1gEFYk0XCg=="
        try PublishedUpdate.verifySignature(originalSignature, archive: original)
        try mustReject("a signature from a different published version") {
            _ = try PublishedUpdate.metadata(archive: archive, signature: originalSignature)
        }
        try mustReject("an archive with changed bytes") {
            var damaged = archive
            damaged[0] ^= 1
            try PublishedUpdate.verifyArchive(damaged)
        }
        try mustReject("a truncated download") { try PublishedUpdate.verifyArchive(archive.dropLast()) }
        try mustReject("malformed signature metadata") {
            _ = try PublishedUpdate.metadata(archive: archive, signature: "not-a-signature")
        }
        let unrelated = Curve25519.Signing.PrivateKey()
        let unrelatedSignature = try unrelated.signature(for: archive).base64EncodedString()
        try mustReject("a valid signature made with an unrelated key") {
            _ = try PublishedUpdate.metadata(archive: archive, signature: unrelatedSignature)
        }
        print("PASS: exact published update verified; trusted historical signature verified; changed/truncated archives, wrong-version signatures, malformed metadata and unrelated keys rejected.")
    }

    static func mustReject(_ label: String, action: () throws -> Void) throws {
        do { try action() } catch { return }
        fatalError("Accepted " + label)
    }
}
