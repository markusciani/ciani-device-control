import CryptoKit
import Foundation

enum PINVerifier {
    static func hash(_ pin: String) -> String {
        SHA256.hash(data: Data("ciani-device-control:\(pin)".utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }
}
