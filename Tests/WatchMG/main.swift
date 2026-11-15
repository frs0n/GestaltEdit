import Foundation

func encoded(_ extra: [String: Any], padding: Int = 0) throws -> Data {
    try PropertyListSerialization.data(fromPropertyList: ["CacheExtra": extra, "CacheData": Data(repeating: 42, count: padding)], format: .binary, options: 0)
}
let watchID = UUID().uuidString
let original = try encoded(["example": "original"], padding: WatchMGWire.chunkSize * 3 + 10)
let replacement = try encoded(["example": "changed"], padding: WatchMGWire.chunkSize * 3 + 10)
var current = original
var backups: [Data] = []
var writes = 0
var backupFails = false
var corruptWrite = false
var time = Date()
let service = WatchMGService(deviceID: watchID, read: { current }, write: {
    writes += 1
    if !corruptWrite { current = try PropertyListSerialization.data(fromPropertyList: $0, format: .binary, options: 0) }
}, backup: {
    if backupFails { throw WatchMGWire.failure("disk full") }
    backups.append($0)
}, now: { time })
func command(_ operation: String, _ values: [String: Any] = [:], deviceID: String = watchID) throws -> [String: Any] {
    var request = values
    request["operation"] = operation
    request["deviceID"] = deviceID
    return try service.handle(request)
}
func rejected(_ description: String, _ body: () throws -> Void) {
    do { try body(); fatalError("Unexpected success: \(description)") } catch {}
}
func begin(_ data: Data, hash: String? = nil) throws -> String {
    try command("begin", ["size": data.count, "hash": hash ?? WatchMGWire.digest(current), "payloadHash": WatchMGWire.digest(data)])["id"] as! String
}
func upload(_ data: Data, id: String) throws {
    for offset in stride(from: 0, to: data.count, by: WatchMGWire.chunkSize) {
        _ = try command("upload", ["id": id, "offset": offset, "data": data.subdata(in: offset..<min(offset + WatchMGWire.chunkSize, data.count))])
    }
}
let header = try command("read")
let snapshotID = header["id"] as! String
var received = Data()
while received.count < (header["size"] as! Int) {
    let bytes = try command("chunk", ["id": snapshotID, "offset": received.count])["data"] as! Data
    precondition(bytes.count <= WatchMGWire.chunkSize)
    received.append(bytes)
}
precondition(received == original && WatchMGWire.digest(received) == header["hash"] as! String)
rejected("another watch") { _ = try command("read", deviceID: UUID().uuidString) }
rejected("negative read offset") { _ = try command("chunk", ["id": snapshotID, "offset": -1]) }
time.addTimeInterval(121)
rejected("expired read") { _ = try command("chunk", ["id": snapshotID, "offset": 0]) }
rejected("oversized upload") { _ = try command("begin", ["size": 5 * 1024 * 1024, "hash": "x", "payloadHash": "x"]) }
let incomplete = try begin(replacement)
rejected("incomplete commit") { _ = try command("commit", ["id": incomplete]) }
rejected("out of order upload") { _ = try command("upload", ["id": incomplete, "offset": 1, "data": Data([1])]) }
try upload(replacement, id: incomplete)
let success = try command("commit", ["id": incomplete])
precondition(success["saved"] as? Bool == true && backups == [original] && writes == 1)
let savedDictionary = try WatchMGWire.decode(current)
let expectedDictionary = try WatchMGWire.decode(replacement)
precondition(NSDictionary(dictionary: savedDictionary).isEqual(to: expectedDictionary))
rejected("duplicate commit") { _ = try command("commit", ["id": incomplete]) }
precondition(writes == 1)
let stale = try begin(original)
try upload(original, id: stale)
current = try encoded(["example": "changed externally"])
rejected("stale snapshot") { _ = try command("commit", ["id": stale]) }
precondition(writes == 1 && backups.count == 1)
let expired = try begin(original)
try upload(original, id: expired)
time.addTimeInterval(121)
rejected("expired commit") { _ = try command("commit", ["id": expired]) }
let invalidData = Data("not a plist".utf8)
let malformed = try begin(invalidData)
try upload(invalidData, id: malformed)
rejected("invalid plist") { _ = try command("commit", ["id": malformed]) }
let corrupt = try begin(original)
try upload(replacement, id: corrupt)
rejected("payload digest mismatch") { _ = try command("commit", ["id": corrupt]) }
precondition(writes == 1 && backups.count == 1)
backupFails = true
let full = try begin(original)
try upload(original, id: full)
rejected("failed backup") { _ = try command("commit", ["id": full]) }
precondition(writes == 1 && backups.count == 1)
backupFails = false
corruptWrite = true
let unverified = try begin(original)
try upload(original, id: unverified)
rejected("verification failure") { _ = try command("commit", ["id": unverified]) }
precondition(writes == 2 && backups.count == 2)
print("Passed: multi-chunk read/write, device isolation, invalid offsets, size limits, interrupted/expired uploads, stale snapshots, digest checks, backup failures, duplicate commits and write verification.")
