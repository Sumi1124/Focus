import Foundation
import CryptoKit

guard CommandLine.arguments.count == 4 else {
    fputs("Usage: verify-published-update.swift appcast.xml public-ed-key.txt published-update.dmg\n", stderr)
    exit(1)
}
let document = try XMLDocument(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1]), options: [])
let items = try document.nodes(forXPath: "/rss/channel/item")
guard let enclosure = items.compactMap({ item in
    item.children?.first(where: { $0.name == "enclosure" }) as? XMLElement
}).first,
let encodedSignature = enclosure.attribute(forName: "sparkle:edSignature")?.stringValue,
let signature = Data(base64Encoded: encodedSignature), signature.count == 64,
let lengthString = enclosure.attribute(forName: "length")?.stringValue,
let expectedLength = Int(lengthString) else {
    fputs("The feed does not contain a valid signed archive enclosure.\n", stderr)
    exit(1)
}
let encodedKey = try String(contentsOfFile: CommandLine.arguments[2], encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
guard let keyData = Data(base64Encoded: encodedKey), keyData.count == 32 else {
    fputs("The trusted update public key is invalid.\n", stderr)
    exit(1)
}
let archive = try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[3]))
let publicKey = try Curve25519.Signing.PublicKey(rawRepresentation: keyData)
guard archive.count == expectedLength, publicKey.isValidSignature(signature, for: archive) else {
    fputs("The published archive did not pass verification with StudyGuard's trusted update key.\n", stderr)
    exit(1)
}
print("PASS: the exact published update archive is signed by StudyGuard's trusted update key")
