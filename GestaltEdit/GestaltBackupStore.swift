import Foundation

enum GestaltBackupPurpose: String {
    case standard = "MobileGestalt"
    case siriAIIdentityRestore = "SiriAI_RestoreIdentity_AfterModelDownload"
}

struct GestaltBackup: Identifiable, Hashable {
    let url: URL
    let createdAt: Date
    let byteCount: Int64

    var id: URL { url }
    var name: String { url.deletingPathExtension().lastPathComponent }
    var purpose: GestaltBackupPurpose {
        if name.hasPrefix(GestaltBackupPurpose.siriAIIdentityRestore.rawValue + "_") { return .siriAIIdentityRestore }
        return .standard
    }
    var displayTitle: String? {
        switch purpose {
        case .standard: nil
        case .siriAIIdentityRestore: String(localized: "After Model Download · Remove Device Spoof")
        }
    }
}

enum GestaltBackupStore {
    static func create(from data: Data, deviceID: String? = nil, purpose: GestaltBackupPurpose = .standard) throws -> GestaltBackup {
        let directory = try backupDirectory(deviceID: deviceID)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss-SSS"
        let url = directory
            .appendingPathComponent("\(purpose.rawValue)_\(formatter.string(from: Date()))")
            .appendingPathExtension("plist")
        try data.write(to: url, options: .atomic)
        return try metadata(for: url)
    }

    static func list(deviceID: String? = nil) throws -> [GestaltBackup] {
        let directory = try backupDirectory(deviceID: deviceID)
        return try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.creationDateKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        )
        .filter { $0.pathExtension == "plist" }
        .map { try metadata(for: $0) }
        .sorted { $0.createdAt > $1.createdAt }
    }

    static func data(for backup: GestaltBackup) throws -> Data {
        try Data(contentsOf: backup.url)
    }

    static func delete(_ backup: GestaltBackup) throws {
        try FileManager.default.removeItem(at: backup.url)
    }

    private static func backupDirectory(deviceID: String?) throws -> URL {
        let documents = try FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let root = documents.appendingPathComponent("MobileGestalt Backups", isDirectory: true)
        // UUIDs come from the helper; never use an arbitrary remote path component.
        let directory: URL
        if let deviceID {
            guard let uuid = UUID(uuidString: deviceID) else {
                throw NSError(domain: "GestaltEdit.Backups", code: 1,
                              userInfo: [NSLocalizedDescriptionKey: String(localized: "Invalid Apple Watch identifier.")])
            }
            directory = root.appendingPathComponent("AppleWatch-\(uuid.uuidString)", isDirectory: true)
        } else {
            directory = root
        }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private static func metadata(for url: URL) throws -> GestaltBackup {
        let values = try url.resourceValues(forKeys: [.creationDateKey, .fileSizeKey])
        return GestaltBackup(
            url: url,
            createdAt: values.creationDate ?? .distantPast,
            byteCount: Int64(values.fileSize ?? 0)
        )
    }
}
