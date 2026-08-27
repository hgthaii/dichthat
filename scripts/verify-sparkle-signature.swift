#!/usr/bin/env swift

import CryptoKit
import Foundation

guard CommandLine.arguments.count == 4 else {
    FileHandle.standardError.write(
        Data("Usage: verify-sparkle-signature.swift <archive> <signature> <Info.plist>\n".utf8)
    )
    exit(EXIT_FAILURE)
}

let archiveURL = URL(fileURLWithPath: CommandLine.arguments[1])
let signatureText = CommandLine.arguments[2]
let infoPlistURL = URL(fileURLWithPath: CommandLine.arguments[3])

let plistData = try Data(contentsOf: infoPlistURL)
guard let plist = try PropertyListSerialization.propertyList(
    from: plistData,
    options: [],
    format: nil
) as? [String: Any],
let publicKeyText = plist["SUPublicEDKey"] as? String,
let publicKeyData = Data(base64Encoded: publicKeyText),
let signatureData = Data(base64Encoded: signatureText)
else {
    FileHandle.standardError.write(Data("Invalid Sparkle public key or signature.\n".utf8))
    exit(EXIT_FAILURE)
}

let archiveData = try Data(contentsOf: archiveURL, options: [.mappedIfSafe])
let publicKey = try Curve25519.Signing.PublicKey(rawRepresentation: publicKeyData)
guard publicKey.isValidSignature(signatureData, for: archiveData) else {
    FileHandle.standardError.write(Data("Sparkle update signature verification failed.\n".utf8))
    exit(EXIT_FAILURE)
}

print("Verified Sparkle EdDSA signature")
