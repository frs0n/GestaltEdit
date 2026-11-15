import Foundation
import CryptoKit

// Keep each interactive WatchConnectivity message below its 65 KB limit.
enum WatchMGWire {
    static let protocolVersion = 1
    static let chunkSize = 24 * 1024
    static func digest(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
    static func decode(_ data: Data) throws -> [String: Any] {
        guard let result = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any],
              result["CacheExtra"] is [String: Any] else { throw failure("Invalid MobileGestalt file.") }
        return result
    }
    static func failure(_ message: String) -> NSError {
        NSError(domain: "GestaltEdit.Watch", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
    }
}
