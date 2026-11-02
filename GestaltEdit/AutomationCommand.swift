import Foundation

enum AutomationCommand {
    static let argument = "--set-us-region"
    static let successMarker = "GESTALT_REGION_SUCCESS"
    static let failureMarker = "GESTALT_REGION_FAILURE"

    static func runIfNeeded() {
        let arguments = CommandLine.arguments
        guard let commandIndex = arguments.firstIndex(of: argument) else { return }

        let modelIndex = arguments.index(after: commandIndex)
        guard modelIndex < arguments.endIndex else {
            finish(marker: failureMarker, message: "Missing regulatory model")
        }

        let regulatoryModel = arguments[modelIndex]
        guard regulatoryModel.range(of: #"^A[0-9]{4}$"#, options: .regularExpression) != nil else {
            finish(marker: failureMarker, message: "Invalid regulatory model: \(regulatoryModel)")
        }

        do {
            let access = GestaltAccess.shared()
            try access.connect()
            let originalData = try access.readGestaltData()
            guard var plist = try access.readGestalt() as? [String: Any],
                  var cacheExtra = plist["CacheExtra"] as? [String: Any] else {
                throw AutomationError.invalidPlist
            }

            cacheExtra["h63QSdBCiT/z0WU6rdQv6Q"] = "LL"
            cacheExtra["yK+xavymRGZ3xWc1tb8XDg"] = "LL/A"
            cacheExtra["97JDvERpVwO+GHtthIh7hA"] = regulatoryModel
            plist["CacheExtra"] = cacheExtra

            _ = try GestaltBackupStore.create(from: originalData)
            try access.saveGestalt(plist)

            guard let verification = try access.readGestalt() as? [String: Any],
                  let verifiedCache = verification["CacheExtra"] as? [String: Any],
                  verifiedCache["h63QSdBCiT/z0WU6rdQv6Q"] as? String == "LL",
                  verifiedCache["yK+xavymRGZ3xWc1tb8XDg"] as? String == "LL/A",
                  verifiedCache["97JDvERpVwO+GHtthIh7hA"] as? String == regulatoryModel else {
                throw AutomationError.verificationFailed
            }

            finish(marker: successMarker, message: regulatoryModel)
        } catch {
            finish(marker: failureMarker, message: error.localizedDescription)
        }
    }

    private static func finish(marker: String, message: String) -> Never {
        let sanitized = message.replacingOccurrences(of: "\n", with: " ")
        let output = "\(marker):\(sanitized)\n"
        FileHandle.standardOutput.write(Data(output.utf8))
        exit(marker == successMarker ? EXIT_SUCCESS : EXIT_FAILURE)
    }
}

private enum AutomationError: LocalizedError {
    case invalidPlist
    case verificationFailed

    var errorDescription: String? {
        switch self {
        case .invalidPlist:
            return "MobileGestalt plist or CacheExtra is invalid"
        case .verificationFailed:
            return "MobileGestalt verification failed"
        }
    }
}
