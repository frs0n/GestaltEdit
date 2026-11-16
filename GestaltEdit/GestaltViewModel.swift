import Combine
import Foundation

@MainActor
final class GestaltViewModel: ObservableObject {
    @Published var plist: GestaltPlist?
    @Published var isDirty = false
    @Published var isBusy = false
    @Published var notice: GestaltNotice?
    @Published private(set) var hasAttemptedLoad = false
    @Published private(set) var backups: [GestaltBackup] = []
    @Published var selectedTweaks: Set<GestaltTweakID> = []
    @Published var dynamicIslandSubtype: Int?
    @Published var changesModelName = false
    @Published var modelName = ""
    @Published var stagesAIRegion = false
    @Published var regionPresetID: String?
    @Published private(set) var isRespringing = false

    enum Device: Hashable { case iPhone, appleWatch }
    @Published private(set) var selectedDevice: Device = .iPhone
    // Keep disclosure state independent of lazy List rows and setup-sheet
    // presentation, which can recreate the selector even without a paired Watch.
    @Published var isDeviceSelectorExpanded = false
    let watch = WatchConnection()
    private var watchDeviceID: String?
    private var watchSnapshot: Data?
    private var watchGeneration = 0
    private var watchSubscription: AnyCancellable?

    init() {
        watchSubscription = watch.$pairingGeneration.dropFirst().sink { [weak self] _ in
            guard let self, self.selectedDevice == .appleWatch else { return }
            self.watchGeneration += 1
            self.clearStagedChanges()
            self.isDirty = false
            self.plist = nil
            self.watchSnapshot = nil
            self.watchDeviceID = nil
            self.backups = []
        }
    }

    func selectDevice(_ device: Device) {
        guard !isBusy, device != selectedDevice else { return }
        selectedDevice = device
        plist = nil
        isDirty = false
        clearStagedChanges()
        watchSnapshot = nil
        watchDeviceID = nil
        backups = []
        load()
    }

    var deviceContextID: String {
        selectedDevice == .iPhone ? "iPhone" : "AppleWatch-\(watchGeneration)-\(watchDeviceID ?? "unavailable")"
    }

    private func clearStagedChanges() {
        selectedTweaks.removeAll()
        dynamicIslandSubtype = nil
        changesModelName = false
        modelName = ""
        stagesAIRegion = false
        regionPresetID = nil
        selectedWatchTweaks.removeAll()
        watchRegionCode = ""
        watchSalesRegion = ""
        watchResolution = -1
        watchUltraFaceClass = 29
    }

    @Published var selectedWatchTweaks: Set<String> = []
    @Published var watchRegionCode = ""
    @Published var watchSalesRegion = ""
    @Published var watchResolution = -1
    @Published var watchUltraFaceClass = 29

    var watchUltraFaceClassOptions: [Int] {
        guard selectedDevice == .appleWatch, let plist else { return [] }
        return WatchTweakCatalog.ultraFaceClasses(plist: plist, build: watch.build)
    }

    var currentWatchUltraFaceClass: Int? {
        guard selectedDevice == .appleWatch, let plist else { return nil }
        return WatchTweakCatalog.currentUltraFaceClass(plist: plist, build: watch.build)
    }

    private func syncWatchUltraFaceClass() {
        watchUltraFaceClass = currentWatchUltraFaceClass ?? watchUltraFaceClassOptions.first ?? 29
    }

    var supportsWatchFaces: Bool {
        guard selectedDevice == .appleWatch, let plist else { return false }
        return WatchTweakCatalog.faceLayout(plist: plist, build: watch.build) != nil
    }

    private let access = GestaltAccess.shared()

    var aiRegionProfile: AIRegionProfile? {
        plist.flatMap(AIRegionProfile.init(plist:))
    }

    var requiresForcedAIEnable: Bool {
        plist.map { AIRegionConfiguration.resolve(for: $0).requiresDeviceSpoofing } ?? false
    }

    var hasStagedTweaks: Bool {
        if selectedDevice == .appleWatch { return stagedChangeCount > 0 }
        return !selectedTweaks.isEmpty
            || dynamicIslandSubtype != nil
            || (changesModelName && !modelName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            || stagesAIRegion
            || regionPresetID != nil
    }

    var stagedChangeCount: Int {
        if selectedDevice == .appleWatch {
            return selectedWatchTweaks.count + (watchRegionCode.isEmpty ? 0 : 1)
                + (watchSalesRegion.isEmpty ? 0 : 1) + (watchResolution >= 0 ? 1 : 0)
        }
        return selectedTweaks.count
            + (dynamicIslandSubtype == nil || selectedTweaks.contains(.supportsDynamicIsland) ? 0 : 1)
            + (changesModelName ? 1 : 0)
            + (stagesAIRegion ? 1 : 0)
            + (regionPresetID == nil ? 0 : 1)
    }

    func load() {
        guard !isBusy else { return }
        hasAttemptedLoad = true
        if selectedDevice == .appleWatch { loadWatch(); return }
        isBusy = true
        notice = nil

        defer { isBusy = false }
        do {
            try access.connect()
            guard let dictionary = try access.readGestalt() as? [String: Any] else {
                throw GestaltEditError.invalidPlist
            }
            plist = GestaltPlist(dict: dictionary)
            isDirty = false
            refreshBackups()
        } catch {
            plist = nil
            report(error)
        }
    }

    var stagedAIRegionPresetID: String? {
        guard stagesAIRegion, let plist else { return regionPresetID }
        return AIRegionConfiguration.resolve(for: plist).changesRegion ? "LL" : regionPresetID
    }

    func setRegionPreset(_ id: String?) {
        guard !stagesAIRegion else { return }
        regionPresetID = id
    }

    func setTweak(_ id: GestaltTweakID, enabled: Bool) {
        selectedTweaks = GestaltTweakCatalog.selecting(id, enabled: enabled, in: selectedTweaks)
    }

    func setAIRegion(enabled: Bool) {
        stagesAIRegion = enabled
        if enabled {
            regionPresetID = nil
        }
        if enabled, requiresForcedAIEnable {
            let twoStage = plist.map { AIRegionConfiguration.resolve(for: $0).usesTwoStageSetup } ?? false
            notice = GestaltNotice(
                kind: .riskWarning,
                message: twoStage
                    ? String(localized: "First, this will temporarily spoof an eligible device. Face ID and dictation may stop working while spoofed. Complete the Siri AI model download in Settings, then open Restore and use “After Model Download · Remove Device Spoof”. After removing the spoof and restarting, Face ID and dictation will work again while Siri AI settings stay enabled. A separate full backup is also saved before setup. System instability is possible.")
                    : String(localized: "This device does not officially support Siri AI. Force enabling spoofs the product, hardware, and CPU model. It may temporarily break Face ID, cause system instability or boot loops, and could require restoring the device. A backup will be created before writing.")
            )
        }
    }

    func applySelectedTweaks() {
        if selectedDevice == .appleWatch { applyWatchTweaks(); return }
        guard !isBusy, var pending = plist else { return }
        do {
            for id in selectedTweaks {
                guard let definition = GestaltTweakCatalog.definition(for: id) else { continue }
                try pending.apply(definition: definition)
            }
            if let dynamicIslandSubtype {
                try pending.setDynamicIslandSubtype(dynamicIslandSubtype)
            }
            if changesModelName {
                let name = modelName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty else { throw GestaltEditError.emptyModelName }
                try pending.setModelName(name)
            }
            if let regionPresetID,
               let region = GestaltRegionPreset.all.first(where: { $0.id == regionPresetID }) {
                pending.apply(region: region)
            }
            var expectedConfiguration: AIRegionConfiguration?
            if stagesAIRegion {
                let configuration = AIRegionConfiguration.resolve(for: pending)
                configuration.apply(to: &pending)
                expectedConfiguration = configuration
            }
            save(pending, expectedAIRegion: expectedConfiguration) { [weak self] in
                self?.selectedTweaks.removeAll()
                self?.dynamicIslandSubtype = nil
                self?.changesModelName = false
                self?.modelName = ""
                self?.stagesAIRegion = false
                self?.regionPresetID = nil
            }
        } catch {
            report(error)
        }
    }

    func applyChanges() {
        guard !isBusy, let plist else { return }
        save(plist, expectedAIRegion: nil)
    }

    func createBackup() {
        guard !isBusy else { return }
        if selectedDevice == .appleWatch { backupWatch(); return }
        isBusy = true
        defer { isBusy = false }
        do {
            try access.connect()
            let data = try access.readGestaltData()
            let backup = try GestaltBackupStore.create(from: data)
            refreshBackups()
            notice = GestaltNotice(
                kind: .backupCreated,
                message: String(
                    format: String(localized: "Saved %@.plist. You can export it from the Backups tab."),
                    backup.name
                )
            )
        } catch {
            report(error)
        }
    }

    func importBackup(from url: URL) {
        guard !isBusy else { return }
        isBusy = true
        defer { isBusy = false }

        guard selectedDevice != .appleWatch || watchDeviceID != nil else {
            report(WatchMGWire.failure(String(localized: "Reload Apple Watch before saving.")))
            return
        }
        let accessed = url.startAccessingSecurityScopedResource()
        defer {
            if accessed { url.stopAccessingSecurityScopedResource() }
        }

        do {
            let data = try Data(contentsOf: url)
            var format = PropertyListSerialization.PropertyListFormat.binary
            guard let dictionary = try PropertyListSerialization.propertyList(
                from: data,
                options: [],
                format: &format
            ) as? [String: Any],
                  dictionary["CacheExtra"] is [String: Any] else {
                throw GestaltEditError.invalidBackup
            }
            let backup = try GestaltBackupStore.create(from: data, deviceID: selectedDevice == .appleWatch ? watchDeviceID : nil)
            refreshBackups()
            notice = GestaltNotice(
                kind: .backupCreated,
                message: String(
                    format: String(localized: "Imported %@ and saved it as %@.plist."),
                    url.lastPathComponent,
                    backup.name
                )
            )
        } catch {
            report(error)
        }
    }

    func restore(_ backup: GestaltBackup) {
        guard !isBusy else { return }
        do {
            let data = try GestaltBackupStore.data(for: backup)
            var format = PropertyListSerialization.PropertyListFormat.binary
            guard let dictionary = try PropertyListSerialization.propertyList(
                from: data,
                options: [],
                format: &format
            ) as? [String: Any] else {
                throw GestaltEditError.invalidBackup
            }
            let snapshot = GestaltPlist(dict: dictionary)
            if backup.purpose == .siriAIIdentityRestore {
                guard selectedDevice == .iPhone,
                      snapshot.dict["CacheExtra"] is [String: Any],
                      let currentDictionary = try access.readGestalt() as? [String: Any] else {
                    throw GestaltEditError.invalidBackup
                }
                let current = GestaltPlist(dict: currentDictionary)
                guard SiriAIIdentityRestore.sameDevice(current, snapshot) else {
                    throw GestaltEditError.wrongDeviceBackup
                }
                let restored = SiriAIIdentityRestore.restoring(current, from: snapshot)
                save(restored, expectedAIRegion: nil,
                     expectedIdentity: SiriAIIdentityRestore.values(in: snapshot)) { [weak self] in
                    self?.clearStagedChanges()
                }
            } else {
                save(snapshot, expectedAIRegion: nil) { [weak self] in self?.clearStagedChanges() }
            }
        } catch {
            report(error)
        }
    }

    func delete(_ backup: GestaltBackup) {
        do {
            try GestaltBackupStore.delete(backup)
            refreshBackups()
        } catch {
            report(error)
        }
    }

    func refreshBackups() {
        do {
            if selectedDevice == .appleWatch && watchDeviceID == nil { backups = []; return }
            backups = try GestaltBackupStore.list(deviceID: selectedDevice == .appleWatch ? watchDeviceID : nil)
        } catch {
            report(error)
        }
    }

    private func siriAIOriginalIdentity(current: GestaltPlist, configuration: AIRegionConfiguration) throws -> GestaltPlist {
        // Reapplying setup must not replace the real identity baseline with an
        // already-spoofed identity. Prefer the dedicated recovery snapshot.
        guard current.cacheExtra["h9jDsbgj7xIVeIQ8S3/X3Q"] as? String == configuration.spoofedProductType else {
            return current
        }
        let saved = try GestaltBackupStore.list()
        let candidates = saved.filter { $0.purpose == .siriAIIdentityRestore }
            + saved.filter { $0.purpose != .siriAIIdentityRestore }.reversed()
        for backup in candidates {
            guard let data = try? GestaltBackupStore.data(for: backup),
                  let dictionary = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
                  dictionary["CacheExtra"] is [String: Any] else { continue }
            let candidate = GestaltPlist(dict: dictionary)
            if SiriAIIdentityRestore.sameDevice(current, candidate),
               candidate.cacheExtra["h9jDsbgj7xIVeIQ8S3/X3Q"] as? String != configuration.spoofedProductType {
                return candidate
            }
        }
        throw GestaltEditError.missingOriginalIdentityBackup
    }

    private func save(
        _ pendingPlist: GestaltPlist,
        expectedAIRegion: AIRegionConfiguration?,
        expectedIdentity: NSDictionary? = nil,
        completion: (() -> Void)? = nil
    ) {
        if selectedDevice == .appleWatch {
            saveWatch(pendingPlist, completion: completion)
            return
        }
        isBusy = true
        notice = nil

        do {
            let originalData = try access.readGestaltData()
            if let configuration = expectedAIRegion, configuration.usesTwoStageSetup {
                guard let originalDictionary = try PropertyListSerialization.propertyList(from: originalData, format: nil) as? [String: Any],
                      originalDictionary["CacheExtra"] is [String: Any] else {
                    throw GestaltEditError.invalidPlist
                }
                let original = GestaltPlist(dict: originalDictionary)
                let baseline = try siriAIOriginalIdentity(current: original, configuration: configuration)
                _ = try GestaltBackupStore.create(from: originalData)
                let recovery = SiriAIIdentityRestore.restoring(pendingPlist, from: baseline)
                let recoveryData = try PropertyListSerialization.data(fromPropertyList: recovery.dict, format: .binary, options: 0)
                _ = try GestaltBackupStore.create(from: recoveryData, purpose: .siriAIIdentityRestore)
            } else {
                _ = try GestaltBackupStore.create(from: originalData)
            }
            try access.saveGestalt(pendingPlist.dict)
            guard let verification = try access.readGestalt() as? [String: Any] else {
                throw GestaltEditError.invalidPlist
            }
            let verifiedPlist = GestaltPlist(dict: verification)
            if let expectedIdentity,
               !expectedIdentity.isEqual(SiriAIIdentityRestore.values(in: verifiedPlist)) {
                throw GestaltEditError.verificationFailed
            }

            if let expectedAIRegion {
                let cacheExtra = verifiedPlist.cacheExtra
                guard AIRegionConfiguration.regionValues(in: verifiedPlist)
                    .isEqual(AIRegionConfiguration.regionValues(in: pendingPlist)) else {
                    throw GestaltEditError.verificationFailed
                }
                if expectedAIRegion.enablesSiriMode,
                   cacheExtra["a3n5T9sFtlyQ74NEp9ESxg"] as? Int != 2 {
                    throw GestaltEditError.verificationFailed
                }
                if expectedAIRegion.requiresDeviceSpoofing {
                    guard cacheExtra["A62OafQ85EJAiiqKn4agtg"] as? Int == 1,
                          cacheExtra["a3n5T9sFtlyQ74NEp9ESxg"] as? Int == 2,
                          cacheExtra["h9jDsbgj7xIVeIQ8S3/X3Q"] as? String == expectedAIRegion.spoofedProductType,
                          cacheExtra["oYicEKzVTz4/CxxE05pEgQ"] as? String == expectedAIRegion.spoofedHardwareModel,
                          cacheExtra["5pYKlGnYYBzGvAlIU8RjEQ"] as? String == expectedAIRegion.spoofedCPUModel else {
                        throw GestaltEditError.verificationFailed
                    }
                }
            }

            plist = verifiedPlist
            isDirty = false
            completion?()
            refreshBackups()
            isBusy = false
            isRespringing = true
        } catch {
            isDirty = true
            refreshBackups()
            report(error)
            isBusy = false
        }
    }

    private func applyWatchTweaks() {
        guard !isBusy, let plist else { return }
        do {
            var pending = plist
            if !watchRegionCode.isEmpty {
                guard WatchTweakCatalog.regions.contains(where: { $0.1 == watchRegionCode }) else { return }
                pending.setCacheExtra(watchRegionCode, forKey: "h63QSdBCiT/z0WU6rdQv6Q")
            }
            if !watchSalesRegion.isEmpty {
                guard WatchTweakCatalog.regions.contains(where: { $0.2 == watchSalesRegion }) else { return }
                let current = "zHeENZu+wbg7PUprwNwBWg", legacy = "yK+xavymRGZ3xWc1tb8XDg"
                let hasCurrent = pending.cacheExtra[current] != nil, hasLegacy = pending.cacheExtra[legacy] != nil
                if hasCurrent || !hasLegacy { pending.setCacheExtra(watchSalesRegion, forKey: current) }
                if hasLegacy { pending.setCacheExtra(watchSalesRegion, forKey: legacy) }
            }
            // Apply the combined AI preset after manual region selections so
            // enabling it cannot leave a newly selected unsupported MG region.
            pending = try WatchTweakCatalog.apply(selectedWatchTweaks, to: pending, build: watch.build,
                                                  regionIdentifier: watch.regionIdentifier,
                                                  ultraFaceClass: watchUltraFaceClass,
                                                  original: selectedWatchTweaks.contains("ultra") ? try originalWatchCache() : nil,
                                                  hardwareIdentifier: watch.hardwareIdentifier)
            if WatchTweakCatalog.resolutions.indices.contains(watchResolution) {
                let resolution = WatchTweakCatalog.resolutions[watchResolution]
                pending.setCacheExtra(resolution.1, forKey: "g7YQ1Djxh4YiKlEeaoGhzg")
                pending.setCacheExtra(resolution.2, forKey: "OjzOua0LkOegX7pQdgMksw")
            }
            saveWatch(pending) { [weak self] in
                self?.clearStagedChanges()
                self?.syncWatchUltraFaceClass()
            }
        } catch { report(error) }
    }

    private func originalWatchCache() throws -> GestaltPlist {
        // Automatic pre-write backups preserve the state before the first Ultra
        // edit, including across reloads and switching back from class 38.
        if let id = watchDeviceID {
            for backup in try GestaltBackupStore.list(deviceID: id).reversed() {
                guard let data = try? GestaltBackupStore.data(for: backup),
                      let dict = try? WatchMGWire.decode(data) else { continue }
                let candidate = GestaltPlist(dict: dict)
                if WatchTweakCatalog.faceLayout(plist: candidate, build: watch.build) != nil {
                    return candidate
                }
            }
        }
        guard let watchSnapshot else { throw WatchMGWire.failure(String(localized: "Reload Apple Watch before saving.")) }
        return GestaltPlist(dict: try WatchMGWire.decode(watchSnapshot))
    }

    private func loadWatch() {
        isBusy = true
        notice = nil
        let generation = watchGeneration
        Task {
            defer { isBusy = false }
            do {
                let id = try await watch.identify()
                let data = try await watch.read(deviceID: id)
                guard generation == watchGeneration else { return }
                if watchDeviceID != id { clearStagedChanges() }
                watchDeviceID = id
                watchSnapshot = data
                plist = GestaltPlist(dict: try WatchMGWire.decode(data))
                if !selectedWatchTweaks.contains("ultra") { syncWatchUltraFaceClass() }
                isDirty = false
                refreshBackups()
            } catch {
                plist = nil
                watchSnapshot = nil
                report(error)
            }
        }
    }

    private func backupWatch() {
        guard let id = watchDeviceID else { return }
        isBusy = true
        Task {
            defer { isBusy = false }
            do {
                let data = try await watch.read(deviceID: id)
                _ = try GestaltBackupStore.create(from: data, deviceID: id)
                refreshBackups()
                notice = GestaltNotice(kind: .backupCreated, message: String(localized: "Apple Watch backup saved on this iPhone."))
            } catch { report(error) }
        }
    }

    private func saveWatch(_ pending: GestaltPlist, completion: (() -> Void)?) {
        guard let id = watchDeviceID, let snapshot = watchSnapshot else {
            report(WatchMGWire.failure(String(localized: "Reload Apple Watch before saving.")))
            return
        }
        isBusy = true
        notice = nil
        let generation = watchGeneration
        Task {
            defer { isBusy = false }
            do {
                let data = try PropertyListSerialization.data(fromPropertyList: pending.dict, format: .binary, options: 0)
                _ = try GestaltBackupStore.create(from: snapshot, deviceID: id)
                try await watch.write(data, deviceID: id, expectedHash: WatchMGWire.digest(snapshot))
                guard generation == watchGeneration else { return }
                let verified = try await watch.read(deviceID: id)
                guard generation == watchGeneration else { return }
                let dictionary = try WatchMGWire.decode(verified)
                guard NSDictionary(dictionary: dictionary).isEqual(to: pending.dict) else {
                    throw GestaltEditError.verificationFailed
                }
                plist = GestaltPlist(dict: dictionary)
                watchSnapshot = verified
                isDirty = false
                completion?()
                refreshBackups()
                // Restart only after both helper-side and iPhone-side readback
                // verification succeeds. Keep restart errors separate: the MG
                // write is already committed and must not be marked dirty/retried.
                do {
                    try await watch.restartInterface(deviceID: id)
                    notice = GestaltNotice(kind: .saved, message: String(localized: "Saved to Apple Watch and verified. Automatic watch interface restart requested."))
                } catch {
                    notice = GestaltNotice(kind: .saved, message: String(
                        format: String(localized: "Saved to Apple Watch and verified, but the automatic interface restart could not be confirmed. Restart Apple Watch manually if needed.\n%@"),
                        error.localizedDescription
                    ))
                }
            } catch {
                // A timeout can occur after commit. Force a fresh read before any retry.
                watchSnapshot = nil
                isDirty = true
                refreshBackups()
                report(error)
            }
        }
    }

    private func report(_ error: Error) {
        notice = GestaltNotice(kind: .error, message: error.localizedDescription)
    }
}

private enum GestaltEditError: LocalizedError {
    case invalidPlist
    case invalidBackup
    case wrongDeviceBackup
    case missingOriginalIdentityBackup
    case verificationFailed
    case emptyModelName

    var errorDescription: String? {
        switch self {
        case .invalidPlist: String(localized: "The MobileGestalt plist is not a valid dictionary.")
        case .wrongDeviceBackup: String(localized: "This Siri AI identity backup belongs to a different device.")
        case .missingOriginalIdentityBackup: String(localized: "This device is already spoofed, but no original identity backup was found. Restore an original MobileGestalt backup before starting Siri AI setup again.")
        case .invalidBackup: String(localized: "The backup is not a valid MobileGestalt plist.")
        case .verificationFailed: String(localized: "The MobileGestalt values after writing do not match the expected values.")
        case .emptyModelName: String(localized: "The device model name cannot be empty.")
        }
    }
}
