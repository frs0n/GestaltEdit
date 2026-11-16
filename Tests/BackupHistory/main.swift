import Foundation

func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    precondition(condition(), message)
}

let original: [String: Any] = ["CacheExtra": ["enabled": false, "removed": "old", "unchanged": 42,
                                           "nested": ["value": "before"], "array": [1, 2]], "top": "old"]
let pending: [String: Any] = ["CacheExtra": ["enabled": true, "added": "new", "unchanged": 42,
                                          "nested": ["value": "after"], "array": [1, 3]], "top": "new"]
let data = try PropertyListSerialization.data(fromPropertyList: original, format: .binary, options: 0)
let record = try GestaltBackupRecord.modification(from: data, to: pending, actions: ["Example tweak"])
expect(record.changes.count == 6, "Include nested, top-level, array, added and removed changes")
expect(record.changes.first { $0.path == ["CacheExtra", "added"] }?.before == nil, "Added field has no original value")
expect(record.changes.first { $0.path == ["CacheExtra", "removed"] }?.after == nil, "Removed field has no new value")
expect(record.changes.first { $0.path == ["CacheExtra", "enabled"] }?.before == "false", "Readable Boolean")
expect(!record.verified, "Preparing a backup does not confirm a write")
let unchanged = try GestaltBackupRecord.modification(from: data, to: original, actions: [])
expect(unchanged.changes.isEmpty, "No false changes for identical plist")
let booleanData = try PropertyListSerialization.data(fromPropertyList: ["value": true], format: .binary, options: 0)
let typed = try GestaltBackupRecord.modification(from: booleanData, to: ["value": 1], actions: [])
expect(typed.changes.count == 1, "Boolean and integer are distinct")
let integerData = try PropertyListSerialization.data(fromPropertyList: ["value": 1], format: .binary, options: 0)
let real = try GestaltBackupRecord.modification(from: integerData, to: ["value": 1.0], actions: [])
expect(real.changes.count == 1, "Integer and real are distinct")

// Use an isolated UUID directory, never the user's existing backup library.
let deviceID = UUID().uuidString
let backup = try GestaltBackupStore.create(from: data, deviceID: deviceID, record: record)
defer { try? FileManager.default.removeItem(at: backup.url.deletingLastPathComponent()) }
let savedData = try GestaltBackupStore.data(for: backup)
expect(savedData == data, "Backup bytes remain unchanged")
let listed = try GestaltBackupStore.list(deviceID: deviceID)
expect(listed.first?.record == record, "History survives reload")
try GestaltBackupStore.markVerified(backup)
let verified = try GestaltBackupStore.list(deviceID: deviceID)
expect(verified.first?.record?.verified == true, "Persist confirmed outcome")
let legacy = try GestaltBackupStore.create(from: data, deviceID: deviceID)
expect(legacy.record == nil, "Legacy snapshots remain readable without invented history")
let corrupt = backup.url.deletingPathExtension().appendingPathExtension("json")
try Data("invalid".utf8).write(to: corrupt)
let recovered = try GestaltBackupStore.list(deviceID: deviceID)
expect(recovered.count == 2, "Damaged history does not hide restorable snapshots")
try GestaltBackupStore.delete(backup)
expect(!FileManager.default.fileExists(atPath: corrupt.path), "Delete associated history")
print("Backup history tests passed")
