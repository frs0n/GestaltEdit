import SwiftUI
import WatchConnectivity
import WatchKit
import Darwin
import Combine

@main
struct GestaltWatchApp: App {
    @StateObject private var helper = WatchMGHelper()
    var body: some Scene {
        WindowGroup {
            VStack(spacing: 12) {
                Image(systemName: "iphone.and.arrow.right.inward").font(.largeTitle)
                Text("GestaltEdit Helper").font(.headline)
                Text(helper.status).font(.footnote).multilineTextAlignment(.center)
            }
            .padding()
        }
    }
}

// No editing UI lives on the watch. Mutations require an immediate iPhone request;
// queued/background application contexts never execute writes.
@MainActor
final class WatchMGHelper: NSObject, ObservableObject, WCSessionDelegate {
    @Published var status = ProcessInfo.processInfo.operatingSystemVersion.majorVersion == 26
        ? String(localized: "watchOS 26 is not supported.")
        : String(localized: "Open GestaltEdit on your iPhone to manage this watch.")
    private let access = GestaltAccess.shared()
    private let identifier: String
    private lazy var service = WatchMGService(
        deviceID: identifier,
        read: { try self.access.readGestaltData() },
        write: { try self.access.saveGestalt($0) },
        backup: { _ = try GestaltBackupStore.create(from: $0) }
    )

    override init() {
        let defaults = UserDefaults.standard
        identifier = defaults.string(forKey: "WatchDeviceID") ?? UUID().uuidString
        defaults.set(identifier, forKey: "WatchDeviceID")
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }

    private func information() -> [String: Any] {
        ["protocol": WatchMGWire.protocolVersion, "deviceID": identifier, "name": WKInterfaceDevice.current().name,
         "version": WKInterfaceDevice.current().systemVersion, "build": systemValue("kern.osversion"),
         "hardwareIdentifier": systemValue("hw.machine"),
         "regionIdentifier": Locale.current.region?.identifier ?? ""]
    }

    private func systemValue(_ key: String) -> String {
        var count = 0
        guard sysctlbyname(key, nil, &count, nil, 0) == 0, count > 0 else { return "" }
        var bytes = [CChar](repeating: 0, count: count)
        guard sysctlbyname(key, &bytes, &count, nil, 0) == 0 else { return "" }
        return String(cString: bytes)
    }

    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor in
            if activationState == .activated { try? session.updateApplicationContext(information()) }
        }
    }
    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        Task { @MainActor in
            do {
                if message["operation"] as? String == "info" { replyHandler(information()); return }
                guard ProcessInfo.processInfo.operatingSystemVersion.majorVersion != 26 else {
                    throw WatchMGWire.failure(String(localized: "watchOS 26 is not supported."))
                }
                if message["operation"] as? String == "respring" {
                    guard message["deviceID"] as? String == identifier else {
                        throw WatchMGWire.failure("The selected Apple Watch has changed. Reload before continuing.")
                    }
                    var error: NSError?
                    guard GestaltWatchStartRespring(&error) else { throw error ?? WatchMGWire.failure("Could not prepare Watch interface restart.") }
                    replyHandler(["accepted": true])
                    return
                }
                let response = try service.handle(message)
                if response["saved"] as? Bool == true {
                    status = String(localized: "Saved. Waiting for the iPhone to restart the watch interface.")
                }
                replyHandler(response)
            }
            catch {
                status = error.localizedDescription
                replyHandler(["error": error.localizedDescription])
            }
        }
    }
}
