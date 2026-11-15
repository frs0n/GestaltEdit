import Foundation

// Runs serially on the helper's main actor. No commands are queued for later delivery.
final class WatchMGService {
    private let deviceID: String
    private let read: () throws -> Data
    private let write: ([String: Any]) throws -> Void
    private let backup: (Data) throws -> Void
    private let now: () -> Date
    private var snapshot: (id: String, data: Data, date: Date)?
    private var upload: (id: String, hash: String, payloadHash: String, size: Int, data: Data, date: Date)?

    init(deviceID: String, read: @escaping () throws -> Data,
         write: @escaping ([String: Any]) throws -> Void, backup: @escaping (Data) throws -> Void, now: @escaping () -> Date = Date.init) {
        self.deviceID = deviceID
        self.read = read
        self.write = write
        self.backup = backup
        self.now = now
    }

    func handle(_ request: [String: Any]) throws -> [String: Any] {
        let operation = request["operation"] as? String ?? ""
        
        guard request["deviceID"] as? String == deviceID else {
            throw WatchMGWire.failure(String(localized: "The selected Apple Watch has changed. Reload before continuing."))
        }
        switch operation {
        case "read":
            let data = try read()
            _ = try WatchMGWire.decode(data)
            let id = UUID().uuidString
            snapshot = (id, data, now())
            return ["id": id, "size": data.count, "hash": WatchMGWire.digest(data)]
        case "chunk":
            guard let snapshot, request["id"] as? String == snapshot.id,
                  now().timeIntervalSince(snapshot.date) < 120,
                  let offset = request["offset"] as? Int, offset >= 0, offset < snapshot.data.count else {
                throw WatchMGWire.failure(String(localized: "Read expired. Reload and try again."))
            }
            return ["data": snapshot.data.subdata(in: offset..<min(offset + WatchMGWire.chunkSize, snapshot.data.count))]
        case "begin":
            guard let size = request["size"] as? Int, size > 0, size <= 4 * 1024 * 1024,
                  let hash = request["hash"] as? String,
                  let payloadHash = request["payloadHash"] as? String else { throw WatchMGWire.failure(String(localized: "Invalid write request.")) }
            let id = UUID().uuidString
            upload = (id, hash, payloadHash, size, Data(), now())
            return ["id": id]
        case "upload":
            guard var pending = upload, request["id"] as? String == pending.id,
                  now().timeIntervalSince(pending.date) < 120,
                  let offset = request["offset"] as? Int, offset == pending.data.count,
                  let data = request["data"] as? Data, !data.isEmpty, data.count <= WatchMGWire.chunkSize,
                  pending.data.count + data.count <= pending.size else {
                throw WatchMGWire.failure(String(localized: "Write expired or incomplete. Reload before retrying."))
            }
            pending.data.append(data)
            upload = pending
            return [:]
        case "commit":
            guard let pending = upload, request["id"] as? String == pending.id,
                  now().timeIntervalSince(pending.date) < 120, pending.data.count == pending.size else {
                throw WatchMGWire.failure(String(localized: "Incomplete write. No changes written."))
            }
            upload = nil // A lost reply must never cause this transaction to execute twice.
            guard WatchMGWire.digest(pending.data) == pending.payloadHash else {
                throw WatchMGWire.failure(String(localized: "Write transfer verification failed. No changes written."))
            }
            let dictionary = try WatchMGWire.decode(pending.data)
            let current = try read()
            guard WatchMGWire.digest(current) == pending.hash else {
                throw WatchMGWire.failure(String(localized: "MobileGestalt changed since it was read. Reload before saving."))
            }
            try backup(current)
            try write(dictionary)
            let verified = try WatchMGWire.decode(read())
            guard NSDictionary(dictionary: verified).isEqual(to: dictionary) else {
                throw WatchMGWire.failure(String(localized: "Write verification failed. The original backup remains on the watch."))
            }
            return ["saved": true]
        default:
            throw WatchMGWire.failure(String(localized: "Unknown helper command."))
        }
    }

}
