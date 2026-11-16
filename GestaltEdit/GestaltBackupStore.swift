import Foundation
import CoreFoundation

enum GestaltBackupPurpose: String {
    case standard = "MobileGestalt"
    case siriAIIdentityRestore = "SiriAI_RestoreIdentity_AfterModelDownload"
}

struct GestaltBackupChange: Codable, Hashable, Identifiable {
    let path: [String]
    let before: String?
    let after: String?
    var id: [String] { path }
}

struct GestaltBackupRecord: Codable, Hashable {
    enum Source: String, Codable { case manual, imported, modification, restore, identityRecovery }
    let source: Source
    let actions: [String]
    let changes: [GestaltBackupChange]
    var verified = false

    static func modification(from data: Data, to dictionary: [String: Any],
                             source: Source = .modification, actions: [String]) throws -> Self {
        guard let original = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
            throw CocoaError(.propertyListReadCorrupt)
        }
        return Self(source: source, actions: actions, changes: differences(original, dictionary))
    }

    // Compare the complete plist, including nested additions and removals.
    private static func differences(_ before: [String: Any], _ after: [String: Any],
                                    path: [String] = []) -> [GestaltBackupChange] {
        Set(before.keys).union(after.keys).sorted().flatMap { key -> [GestaltBackupChange] in
            let old = before[key], new = after[key], currentPath = path + [key]
            if let old = old as? [String: Any], let new = new as? [String: Any] {
                return differences(old, new, path: currentPath)
            }
            if let old, let new,
               serializedValue(old) == serializedValue(new) { return [] }
            return [.init(path: currentPath, before: old.map(valueDescription), after: new.map(valueDescription))]
        }
    }

    private static func serializedValue(_ value: Any) -> Data? {
        try? PropertyListSerialization.data(fromPropertyList: [value], format: .xml, options: 0)
    }

    private static func valueDescription(_ value: Any) -> String {
        if let text = value as? String { return String(reflecting: text) }
        if let number = value as? NSNumber {
            if CFGetTypeID(number) == CFBooleanGetTypeID() { return number.boolValue ? "true" : "false" }
            if ["f", "d"].contains(String(cString: number.objCType)) { return String(number.doubleValue) }
            return number.stringValue
        }
        // XML preserves arrays, dictionaries, dates and binary data without truncation.
        guard let data = try? PropertyListSerialization.data(fromPropertyList: [value], format: .xml, options: 0),
              let xml = String(data: data, encoding: .utf8),
              let start = xml.range(of: "<array>\n"),
              let end = xml.range(of: "</array>", options: .backwards) else { return String(describing: value) }
        return xml[start.upperBound..<end.lowerBound].trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct GestaltBackup: Identifiable, Hashable {
    let url: URL
    let createdAt: Date
    let byteCount: Int64
    var record: GestaltBackupRecord? = nil

    var id: URL { url }
    var name: String { url.deletingPathExtension().lastPathComponent }
    var purpose: GestaltBackupPurpose {
        if name.hasPrefix(GestaltBackupPurpose.siriAIIdentityRestore.rawValue + "_") { return .siriAIIdentityRestore }
        return .standard
    }
    var reason: String {
        guard let record else { return displayTitle ?? String(localized: "Reason Not Recorded") }
        if !record.actions.isEmpty { return record.actions.joined(separator: " · ") }
        switch record.source {
        case .manual: return String(localized: "Manual Backup")
        case .imported: return String(localized: "Imported Backup")
        case .modification: return String(localized: "Field Changes")
        case .restore: return String(localized: "Restore Backup")
        case .identityRecovery: return displayTitle ?? String(localized: "Remove Device Spoof")
        }
    }
    var displayTitle: String? {
        switch purpose {
        case .standard: nil
        case .siriAIIdentityRestore: String(localized: "After Model Download · Remove Device Spoof")
        }
    }
}

enum GestaltBackupStore {
    static func create(from data: Data, deviceID: String? = nil, purpose: GestaltBackupPurpose = .standard,
                       record: GestaltBackupRecord? = nil) throws -> GestaltBackup {
        let directory = try backupDirectory(deviceID: deviceID)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss-SSS"
        let url = directory
            .appendingPathComponent("\(purpose.rawValue)_\(formatter.string(from: Date()))_\(UUID().uuidString)")
            .appendingPathExtension("plist")
        try data.write(to: url, options: .atomic)
        if let record {
            do { try JSONEncoder().encode(record).write(to: recordURL(for: url), options: .atomic) }
            catch {
                try? FileManager.default.removeItem(at: url)
                throw error
            }
        }
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

    static func markVerified(_ backup: GestaltBackup) throws {
        guard var record = backup.record else { return }
        record.verified = true
        try JSONEncoder().encode(record).write(to: recordURL(for: backup.url), options: .atomic)
    }

    private static func recordURL(for url: URL) -> URL {
        url.deletingPathExtension().appendingPathExtension("json")
    }

    static func delete(_ backup: GestaltBackup) throws {
        let recordURL = recordURL(for: backup.url)
        if FileManager.default.fileExists(atPath: recordURL.path) {
            try FileManager.default.removeItem(at: recordURL)
        }
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
            byteCount: Int64(values.fileSize ?? 0),
            record: (try? Data(contentsOf: recordURL(for: url))).flatMap { try? JSONDecoder().decode(GestaltBackupRecord.self, from: $0) }
        )
    }
}
