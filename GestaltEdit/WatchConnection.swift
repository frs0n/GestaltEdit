import Foundation
import Combine
import WatchConnectivity

@MainActor
final class WatchConnection: NSObject, ObservableObject, WCSessionDelegate {
    @Published private(set) var isPaired = false
    @Published private(set) var isInstalled = false
    @Published private(set) var isReachable = false
    @Published private(set) var deviceID: String?
    @Published private(set) var name = "Apple Watch"
    @Published private(set) var version = ""
    @Published private(set) var build = ""
    @Published private(set) var regionIdentifier = ""
    @Published private(set) var hardwareIdentifier = ""
    @Published private(set) var pairingGeneration = 0
    private let session = WCSession.default

    override init() {
        super.init()
        if WCSession.isSupported() {
            session.delegate = self
            session.activate()
        }
    }

    func refresh() {
        guard WCSession.isSupported() else { return }
        isPaired = session.isPaired
        isInstalled = session.isWatchAppInstalled
        isReachable = session.activationState == .activated && session.isReachable
        if !isPaired || !isInstalled {
            deviceID = nil
            name = "Apple Watch"
            version = ""
            build = ""
            regionIdentifier = ""
            hardwareIdentifier = ""
        }
    }

    func identify() async throws -> String {
        let response = try await request(["operation": "info"])
        guard response["protocol"] as? Int == WatchMGWire.protocolVersion,
              let id = response["deviceID"] as? String, UUID(uuidString: id) != nil else { throw WatchMGWire.failure(String(localized: "Invalid helper response.")) }
        deviceID = id
        name = response["name"] as? String ?? "Apple Watch"
        version = response["version"] as? String ?? ""
        build = response["build"] as? String ?? ""
        regionIdentifier = response["regionIdentifier"] as? String ?? ""
        hardwareIdentifier = response["hardwareIdentifier"] as? String ?? ""
        return id
    }

    func read(deviceID: String) async throws -> Data {
        let header = try await request(["operation": "read", "deviceID": deviceID])
        guard let id = header["id"] as? String, let size = header["size"] as? Int,
              size > 0, size <= 4 * 1024 * 1024, let hash = header["hash"] as? String else {
            throw WatchMGWire.failure(String(localized: "Invalid helper response."))
        }
        var data = Data()
        while data.count < size {
            let chunk = try await request(["operation": "chunk", "deviceID": deviceID, "id": id, "offset": data.count])
            guard let bytes = chunk["data"] as? Data, !bytes.isEmpty,
                  bytes.count <= WatchMGWire.chunkSize, data.count + bytes.count <= size else {
                throw WatchMGWire.failure(String(localized: "Incomplete Apple Watch response."))
            }
            data.append(bytes)
        }
        guard WatchMGWire.digest(data) == hash else { throw WatchMGWire.failure(String(localized: "Apple Watch transfer verification failed.")) }
        return data
    }

    func write(_ data: Data, deviceID: String, expectedHash: String) async throws {
        let response = try await request(["operation": "begin", "deviceID": deviceID, "size": data.count, "hash": expectedHash, "payloadHash": WatchMGWire.digest(data)])
        guard let id = response["id"] as? String else { throw WatchMGWire.failure(String(localized: "Invalid helper response.")) }
        for offset in stride(from: 0, to: data.count, by: WatchMGWire.chunkSize) {
            _ = try await request(["operation": "upload", "deviceID": deviceID, "id": id, "offset": offset,
                                  "data": data.subdata(in: offset..<min(offset + WatchMGWire.chunkSize, data.count))])
        }
        let result = try await request(["operation": "commit", "deviceID": deviceID, "id": id])
        guard result["saved"] as? Bool == true else { throw WatchMGWire.failure(String(localized: "Save was not confirmed. Reload before retrying.")) }
    }

    func restartInterface(deviceID: String) async throws {
        let result = try await request(["operation": "respring", "deviceID": deviceID])
        guard result["accepted"] as? Bool == true else {
            throw WatchMGWire.failure(String(localized: "Watch interface restart was not accepted."))
        }
    }

    private func request(_ message: [String: Any]) async throws -> [String: Any] {
        refresh()
        guard isPaired, isInstalled, isReachable else {
            throw WatchMGWire.failure(String(localized: "Open GestaltEdit Helper on your Apple Watch and keep it nearby, then reload."))
        }
        // WCSession provides a timeout error; never retry a mutation automatically.
        return try await withCheckedThrowingContinuation { continuation in
            session.sendMessage(message, replyHandler: { continuation.resume(returning: $0) },
                                errorHandler: { continuation.resume(throwing: $0) })
        }.checkedHelperResponse()
    }

    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor in refresh() }
    }
    nonisolated func sessionWatchStateDidChange(_ session: WCSession) {
        Task { @MainActor in refresh() }
    }
    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in refresh() }
    }
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {
        Task { @MainActor in
            deviceID = nil
            pairingGeneration += 1
            isReachable = false
        }
    }
    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
}

private extension Dictionary where Key == String, Value == Any {
    func checkedHelperResponse() throws -> Self {
        if let error = self["error"] as? String { throw WatchMGWire.failure(error) }
        return self
    }
}
