import Foundation
import Security

/// Persists the device's original MobileGestalt region values before the
/// "Enable Siri AI (US Region)" toggle overwrites them.
///
/// Storage uses the iOS Keychain rather than the App's sandbox because
/// Keychain items survive App uninstallation by default on iOS. The entry
/// is App-private (scoped by service + account) and marked
/// ThisDeviceOnly, so it is excluded even from encrypted iTunes/Finder
/// backups and can never migrate to another device — restoring a
/// different device's "original region" would be meaningless.
///
/// Lifecycle:
/// - Save once, right before the first AI-region apply on a given device.
/// - Restore + clear when the user turns the toggle off.
/// - If a restore is requested but no backup definitively exists (e.g. AI
///   was enabled by another tool), all affected keys are removed as a
///   fallback so the device returns to the "AI unconfigured" state.
///   Only `errSecItemNotFound` takes this destructive path; transient
///   Keychain failures throw and leave the plist untouched.
enum AIRegionBackupStore {
    private static let service = "me.ssus.gestaltedit.aiRegionBackup"
    private static let account = "originalRegionValues"

    /// All CacheExtra keys that the AI-region toggle may overwrite.
    /// Backing up and restoring this exact set keeps the device's state
    /// reversible. The apply-side writer asserts against this list, so
    /// the two can never drift apart.
    static let affectedKeys: [String] = [
        "h63QSdBCiT/z0WU6rdQv6Q", // RegionCode ("LL")
        "yK+xavymRGZ3xWc1tb8XDg", // RegionCodeWithSlash ("LL/A")
        "97JDvERpVwO+GHtthIh7hA", // RegulatoryModel
        "A62OafQ85EJAiiqKn4agtg", // DeviceIdentitySpoof flag
        "h9jDsbgj7xIVeIQ8S3/X3Q", // SpoofedProductType
        "oYicEKzVTz4/CxxE05pEgQ", // SpoofedHardwareModel
        "5pYKlGnYYBzGvAlIU8RjEQ"  // SpoofedCPUModel
    ]

    /// One backed-up CacheExtra entry. `data` holds the binary
    /// property-list serialization of the original value; `present ==
    /// false` records that the key did not exist before the spoof (so a
    /// restore removes it again).
    private struct Entry: Codable {
        let present: Bool
        let data: Data?
    }

    /// Versioned snapshot envelope. Future format changes should bump
    /// `version` and migrate in ``restore(into:)`` before decoding.
    private struct Snapshot: Codable {
        let version: Int
        let entries: [String: Entry]

        static let currentVersion = 1
    }

    /// Snapshots the current values of ``affectedKeys`` from `plist`
    /// into the Keychain. A key that is absent in `plist` is recorded as
    /// missing so it can be removed on restore.
    static func save(from plist: GestaltPlist) throws {
        var entries: [String: Entry] = [:]
        for key in affectedKeys {
            if let value = plist.cacheExtra[key] {
                entries[key] = Entry(
                    present: true,
                    data: try PropertyListSerialization.data(
                        fromPropertyList: value,
                        format: .binary,
                        options: 0
                    )
                )
            } else {
                entries[key] = Entry(present: false, data: nil)
            }
        }
        let snapshot = Snapshot(
            version: Snapshot.currentVersion,
            entries: entries
        )
        try write(data: try PropertyListEncoder().encode(snapshot))
    }

    /// Restores the snapshotted values back into `plist`. Keys that were
    /// originally missing are removed from CacheExtra; keys that had a
    /// value are written back. If no backup exists, all affected keys
    /// are removed as a fallback. A transient Keychain failure throws
    /// and leaves `plist` untouched — it must never be mistaken for
    /// "no backup", because the fallback deletes data.
    static func restore(into plist: inout GestaltPlist) throws {
        switch read() {
        case .notFound:
            // No backup on this device (AI was enabled by another tool,
            // or the entry was wiped): fall back to removing every
            // affected key so no half-applied spoof survives.
            for key in affectedKeys {
                plist.removeCacheExtraValue(forKey: key)
            }
        case .failed(let status):
            throw AIRegionBackupError.keychainReadFailed(status: status)
        case .found(let data):
            let snapshot: Snapshot
            do {
                snapshot = try PropertyListDecoder().decode(Snapshot.self, from: data)
            } catch {
                throw AIRegionBackupError.corruptBackup
            }
            guard snapshot.version <= Snapshot.currentVersion else {
                // Written by a newer build; migrate here once a v2
                // format exists. Until then, refuse rather than guess.
                throw AIRegionBackupError.corruptBackup
            }

            for key in affectedKeys {
                guard let entry = snapshot.entries[key] else {
                    // Backed up before this key was tracked; leave as-is.
                    continue
                }
                if entry.present {
                    guard let valueData = entry.data else {
                        // Marked as present but the payload is gone:
                        // corruption, not "originally missing".
                        throw AIRegionBackupError.corruptBackup
                    }
                    let value = try PropertyListSerialization.propertyList(
                        from: valueData,
                        options: [],
                        format: nil
                    )
                    plist.setCacheExtra(value, forKey: key)
                } else {
                    plist.removeCacheExtraValue(forKey: key)
                }
            }
        }
    }

    /// Deletes the Keychain entry. Safe to call when no backup exists.
    static func clear() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }

    static func hasBackup() -> Bool {
        if case .found = read() { return true }
        return false
    }

    // MARK: - Keychain primitives

    /// Distinguishes "definitively no backup" from "could not read".
    /// Only `.notFound` may trigger destructive fallbacks downstream.
    private enum ReadOutcome {
        case found(Data)
        case notFound
        case failed(OSStatus)
    }

    private static func write(data: Data) throws {
        let baseQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let attributes: [String: Any] = [
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            kSecValueData as String: data
        ]
        // Add-or-update instead of clear-then-add: closing the window in
        // which a concurrent reader could observe "no backup exists".
        var status = SecItemAdd(
            baseQuery.merging(attributes) { _, new in new } as CFDictionary,
            nil
        )
        if status == errSecDuplicateItem {
            status = SecItemUpdate(
                baseQuery as CFDictionary,
                attributes as CFDictionary
            )
        }
        guard status == errSecSuccess else {
            throw AIRegionBackupError.keychainWriteFailed(status: status)
        }
    }

    private static func read() -> ReadOutcome {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        switch status {
        case errSecSuccess:
            return .found(result as? Data ?? Data())
        case errSecItemNotFound:
            return .notFound
        default:
            return .failed(status)
        }
    }
}

enum AIRegionBackupError: LocalizedError {
    case keychainWriteFailed(status: OSStatus)
    case keychainReadFailed(status: OSStatus)
    case corruptBackup

    var errorDescription: String? {
        switch self {
        case .keychainWriteFailed(let status):
            String(localized: "Failed to save AI region backup to Keychain (status \(status)).")
        case .keychainReadFailed(let status):
            String(localized: "Failed to read AI region backup from Keychain (status \(status)). Nothing was changed; try again later.")
        case .corruptBackup:
            String(localized: "The stored AI region backup is unreadable. Nothing was changed; restore a plist backup manually if needed.")
        }
    }
}
