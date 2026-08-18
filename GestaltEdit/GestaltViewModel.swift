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
    @Published private(set) var isRespringing = false

    /// Snapshot of which tweaks / AI region were already active in the plist
    /// at load time. Used so that ``hasStagedTweaks`` only reports genuine
    /// new changes rather than re-counting already-applied values.
    private var appliedTweaks: Set<GestaltTweakID> = []
    private var appliedAIRegion = false

    private let access = GestaltAccess.shared()

    var aiRegionProfile: AIRegionProfile? {
        plist.flatMap(AIRegionProfile.init(plist:))
    }

    var requiresForcedAIEnable: Bool {
        plist != nil && aiRegionProfile == nil
    }

    var isAIRegionConfigured: Bool {
        guard let profile = aiRegionProfile,
              let cacheExtra = plist?.cacheExtra else { return false }
        return cacheExtra["h63QSdBCiT/z0WU6rdQv6Q"] as? String == "LL"
            && cacheExtra["yK+xavymRGZ3xWc1tb8XDg"] as? String == "LL/A"
            && cacheExtra["97JDvERpVwO+GHtthIh7hA"] as? String == profile.regulatoryModel
    }

    var hasStagedTweaks: Bool {
        // Symmetric difference so that turning OFF an already-applied tweak
        // also counts as a staged change, not just turning one on.
        !selectedTweaks.symmetricDifference(appliedTweaks).isEmpty
            || dynamicIslandSubtype != nil
            || (changesModelName && !modelName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            || (stagesAIRegion != appliedAIRegion)
    }

    var stagedChangeCount: Int {
        selectedTweaks.symmetricDifference(appliedTweaks).count
            + (dynamicIslandSubtype == nil ? 0 : 1)
            + (changesModelName ? 1 : 0)
            + (stagesAIRegion != appliedAIRegion ? 1 : 0)
    }

    func load() {
        guard !isBusy else { return }
        hasAttemptedLoad = true
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
            if !hasStagedTweaks {
                syncStateFromPlist()
            }
            refreshBackups()
        } catch {
            plist = nil
            report(error)
        }
    }

    /// Reads the current plist and populates every toggle / picker so that
    /// the UI reflects the device's actual MobileGestalt state instead of
    /// always starting from an empty baseline.
    private func syncStateFromPlist() {
        guard let plist else { return }

        let applied = Set(
            GestaltTweakCatalog.definitions
                .filter { plist.isTweakApplied($0) }
                .map { $0.id }
        )
        selectedTweaks = applied
        appliedTweaks = applied

        stagesAIRegion = isAIRegionConfigured
        appliedAIRegion = stagesAIRegion

        if let artwork = plist.cacheExtra["oPeik/9e8lQWMszEjbPzng"] as? [String: Any],
           let name = artwork["ArtworkDeviceProductDescription"] as? String {
            modelName = name
        }
        changesModelName = false
        dynamicIslandSubtype = nil
    }

    func setTweak(_ id: GestaltTweakID, enabled: Bool) {
        if enabled {
            selectedTweaks.insert(id)
            if id == .enableLiquidGlassLowPerformance {
                selectedTweaks.remove(.disableLiquidGlassLowPerformance)
            } else if id == .disableLiquidGlassLowPerformance {
                selectedTweaks.remove(.enableLiquidGlassLowPerformance)
            }
        } else {
            selectedTweaks.remove(id)
        }
    }

    func setAIRegion(enabled: Bool) {
        stagesAIRegion = enabled
        if enabled, requiresForcedAIEnable {
            notice = GestaltNotice(
                kind: .riskWarning,
                message: String(localized: "This device does not officially support Siri AI. Force enabling spoofs the product, hardware, and CPU model. It may temporarily break Face ID, cause system instability or boot loops, and could require restoring the device. A backup will be created before writing.")
            )
        }
    }

    func applySelectedTweaks() {
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
            var expectedConfiguration: AIRegionConfiguration?
            if stagesAIRegion && !appliedAIRegion {
                // First-time enable: snapshot the device's original region
                // values to the Keychain before overwriting them, so a later
                // toggle-off can restore them exactly — even if GestaltEdit
                // has been uninstalled and reinstalled in between.
                try AIRegionBackupStore.save(from: pending)
                let configuration = AIRegionConfiguration.resolve(for: pending)
                applyAIRegion(into: &pending, configuration: configuration)
                expectedConfiguration = configuration
            } else if !stagesAIRegion && appliedAIRegion {
                // Turning off: restore the original values that were backed
                // up when AI was enabled, then drop the Keychain entry so a
                // subsequent enable starts from a fresh snapshot.
                try AIRegionBackupStore.restore(into: &pending)
                AIRegionBackupStore.clear()
            }
            // When stagesAIRegion == appliedAIRegion the user did not flip
            // the AI toggle, so the AI keys are left untouched.
            save(pending, expectedAIRegion: expectedConfiguration) { [weak self] in
                self?.syncStateFromPlist()
            }
        } catch {
            report(error)
        }
    }

    func applyChanges() {
        guard !isBusy, let plist else { return }
        save(plist, expectedAIRegion: nil)
    }

    /// Writes the US-region AI capability values into `pending`. Split out
    /// from ``applySelectedTweaks`` so the enable path stays readable.
    /// Every key written here must be listed in
    /// ``AIRegionBackupStore/affectedKeys`` for the backup/restore cycle
    /// to stay reversible; the assertion fails fast in debug builds if
    /// the two lists ever drift apart.
    private func applyAIRegion(into pending: inout GestaltPlist, configuration: AIRegionConfiguration) {
        let profile = configuration.profile
        var values: [String: Any] = [
            "h63QSdBCiT/z0WU6rdQv6Q": "LL",
            "yK+xavymRGZ3xWc1tb8XDg": "LL/A",
            "97JDvERpVwO+GHtthIh7hA": profile.regulatoryModel
        ]
        if let productType = configuration.spoofedProductType,
           let hardwareModel = configuration.spoofedHardwareModel,
           let cpuModel = configuration.spoofedCPUModel {
            values["A62OafQ85EJAiiqKn4agtg"] = 1
            values["h9jDsbgj7xIVeIQ8S3/X3Q"] = productType
            values["oYicEKzVTz4/CxxE05pEgQ"] = hardwareModel
            values["5pYKlGnYYBzGvAlIU8RjEQ"] = cpuModel
        }
        assert(
            values.keys.allSatisfy { AIRegionBackupStore.affectedKeys.contains($0) },
            "applyAIRegion writes keys that AIRegionBackupStore does not back up"
        )
        for (key, value) in values {
            pending.setCacheExtra(value, forKey: key)
        }
    }

    func createBackup() {
        guard !isBusy else { return }
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
            let backup = try GestaltBackupStore.create(from: data)
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
            save(GestaltPlist(dict: dictionary), expectedAIRegion: nil)
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
            backups = try GestaltBackupStore.list()
        } catch {
            report(error)
        }
    }

    private func save(
        _ pendingPlist: GestaltPlist,
        expectedAIRegion: AIRegionConfiguration?,
        completion: (() -> Void)? = nil
    ) {
        isBusy = true
        notice = nil

        do {
            let originalData = try access.readGestaltData()
            _ = try GestaltBackupStore.create(from: originalData)
            try access.saveGestalt(pendingPlist.dict)
            guard let verification = try access.readGestalt() as? [String: Any] else {
                throw GestaltEditError.invalidPlist
            }
            let verifiedPlist = GestaltPlist(dict: verification)

            if let expectedAIRegion {
                let cacheExtra = verifiedPlist.cacheExtra
                guard cacheExtra["h63QSdBCiT/z0WU6rdQv6Q"] as? String == "LL",
                      cacheExtra["yK+xavymRGZ3xWc1tb8XDg"] as? String == "LL/A",
                      cacheExtra["97JDvERpVwO+GHtthIh7hA"] as? String == expectedAIRegion.profile.regulatoryModel else {
                    throw GestaltEditError.verificationFailed
                }
                if expectedAIRegion.requiresDeviceSpoofing {
                    guard cacheExtra["A62OafQ85EJAiiqKn4agtg"] as? Int == 1,
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
            report(error)
            isBusy = false
        }
    }

    private func report(_ error: Error) {
        notice = GestaltNotice(kind: .error, message: error.localizedDescription)
    }
}

private enum GestaltEditError: LocalizedError {
    case invalidPlist
    case invalidBackup
    case verificationFailed
    case emptyModelName

    var errorDescription: String? {
        switch self {
        case .invalidPlist: String(localized: "The MobileGestalt plist is not a valid dictionary.")
        case .invalidBackup: String(localized: "The backup is not a valid MobileGestalt plist.")
        case .verificationFailed: String(localized: "The MobileGestalt values after writing do not match the expected values.")
        case .emptyModelName: String(localized: "The device model name cannot be empty.")
        }
    }
}
