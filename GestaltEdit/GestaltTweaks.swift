import Foundation

enum GestaltTweakCategory: String, CaseIterable, Identifiable {
    case region
    case display
    case hardware
    case audio
    case ipad
    case settings
    case internalFeatures

    var id: String { rawValue }

    var label: String {
        switch self {
        case .display: String(localized: "Display & Appearance")
        case .hardware: String(localized: "Hardware Capabilities")
        case .audio: String(localized: "Audio")
        case .ipad: String(localized: "iPad Capabilities")
        case .region: String(localized: "Region")
        case .settings: String(localized: "Settings Shortcuts")
        case .internalFeatures: String(localized: "Internal & Research")
        }
    }
}

enum GestaltTweakID: String, CaseIterable, Identifiable {
    case supportsDynamicIsland
    case bootChime
    case chargeLimit
    case tapToWake
    case cameraButton
    case disableParallax
    case enableLiquidGlassLowPerformance
    case disableLiquidGlassLowPerformance
    case stageManager
    case iPadOS
    case iPadApps
    case pencil
    case actionButton
    case internalInstall
    case internalStorage
    case securityResearchDevice
    case collisionSOS
    case alwaysOnDisplay
    case alwaysOnDisplayVibrancy

    case hdrPhotoDisplay
    case aodHighLuminance
    case aodFlipbook
    case pulseWidthModulation
    case displayPort
    case audioMix
    case spatialFaceTimeAudio
    case internalSettings

    var id: String { rawValue }
}

struct GestaltTweakDefinition: Identifiable {
    let id: GestaltTweakID
    let category: GestaltTweakCategory
    let title: String
    let detail: String
    let values: [String: Any]
    var isRisky = false
    var showsDetails = false
    var minimumOSMajor = 26
    var minimumOSMinor = 0

    func isAvailable(on version: OperatingSystemVersion = ProcessInfo.processInfo.operatingSystemVersion) -> Bool {
        version.majorVersion > minimumOSMajor
            || (version.majorVersion == minimumOSMajor && version.minorVersion >= minimumOSMinor)
    }
}

enum GestaltTweakCatalog {
    static let definitions: [GestaltTweakDefinition] = [
        // Capability mappings: PoomSmart/MGKeys (mapping.h, keys_versions.py).
        // Catalog comparison: huamidev/GestaltX, rooootdev/mond. A capability
        // override is not proof that the corresponding hardware/service exists.
        .init(id: .hdrPhotoDisplay, category: .display, title: String(localized: "HDR Photos"), detail: String(localized: "Advertises HDR photo display support. The display and photo must support HDR."), values: ["a1r7npIrhXsZ7SmKRKC1eA": 1], isRisky: false, showsDetails: true, minimumOSMajor: 26, minimumOSMinor: 0),
        .init(id: .aodHighLuminance, category: .display, title: String(localized: "Brighter Always-On Display"), detail: String(localized: "Allows higher Always-On brightness on supported panels. May increase power use and burn-in risk."), values: ["7brdL5xrEUWnlF9C0kdg5A": 1], isRisky: true, showsDetails: true, minimumOSMajor: 27, minimumOSMinor: 0),
        .init(id: .aodFlipbook, category: .display, title: String(localized: "Always-On Widgets"), detail: String(localized: "Advertises support for Always-On flipbook widgets. Availability depends on the system and widgets."), values: ["aoJSd/MXk7M40NgXTM6x+g": 1], isRisky: false, showsDetails: true, minimumOSMajor: 26, minimumOSMinor: 0),
        .init(id: .pulseWidthModulation, category: .settings, title: String(localized: "PWM Display Settings"), detail: String(localized: "Advertises pulse-width maximization support. Does not change the physical display or guarantee a different dimming method."), values: ["6IejgN+1Fmu5/QrZFOIeNw": 1], isRisky: false, showsDetails: true, minimumOSMajor: 26, minimumOSMinor: 0),
        .init(id: .displayPort, category: .settings, title: String(localized: "DisplayPort Output"), detail: String(localized: "Advertises DisplayPort output support. A compatible port, adapter and display are still required."), values: ["CoWnN4xo783YGn4wLrUatA": 1], isRisky: false, showsDetails: true, minimumOSMajor: 26, minimumOSMinor: 0),
        .init(id: .audioMix, category: .audio, title: String(localized: "Audio Mix"), detail: String(localized: "Advertises Audio Mix support. Requires compatible recordings and system support."), values: ["aVL5GE3tx0LSCI/ErfrJGA": 1], isRisky: false, showsDetails: true, minimumOSMajor: 26, minimumOSMinor: 0),
        .init(id: .spatialFaceTimeAudio, category: .audio, title: String(localized: "FaceTime Spatial Audio"), detail: String(localized: "Advertises spatial audio playback for FaceTime. Availability depends on the device and call."), values: ["/EVOCjM/Nmb2roP5ebtEFA": 1], isRisky: false, showsDetails: true, minimumOSMajor: 26, minimumOSMinor: 0),
        .init(id: .internalSettings, category: .internalFeatures, title: String(localized: "Internal Settings Bundle"), detail: String(localized: "Advertises the internal Settings bundle. May affect system services and does not install missing internal components."), values: ["Oji6HRoPi7rH7HPdWVakuw": 1], isRisky: true, showsDetails: true, minimumOSMajor: 26, minimumOSMinor: 0),
        .init(id: .supportsDynamicIsland, category: .display, title: String(localized: "Dynamic Island"), detail: String(localized: "Enables Dynamic Island. Choose a layout only if its position needs adjusting."), values: ["YlEtTtHlNesRBMal1CqRaA": 1]),
        .init(id: .alwaysOnDisplay, category: .display, title: String(localized: "Always-On Display"), detail: String(localized: "May increase burn-in risk on unsupported devices."), values: ["2OOJf1VhaM7NxfRok3HbWQ": 1, "j8/Omm6s1lsmTDFsXjsBfA": 1], isRisky: true),
        .init(id: .alwaysOnDisplayVibrancy, category: .display, title: String(localized: "AOD Vibrancy"), detail: String(localized: "Use this when AOD rendering looks incorrect."), values: ["ykpu7qyhqFweVMKtxNylWA": 1]),
        .init(id: .disableParallax, category: .display, title: String(localized: "Disable Wallpaper Parallax"), detail: String(localized: "Stops wallpaper motion based on device movement."), values: ["UIParallaxCapability": 0]),
        .init(id: .enableLiquidGlassLowPerformance, category: .display, title: String(localized: "Enable Liquid Glass Low-Performance Mode"), detail: String(localized: "For iOS 26 and later."), values: ["SAGvsp6O6kAQ4fEfDJpC4Q": 1]),
        .init(id: .disableLiquidGlassLowPerformance, category: .display, title: String(localized: "Disable Liquid Glass Low-Performance Mode"), detail: String(localized: "Mutually exclusive with the option above."), values: ["SAGvsp6O6kAQ4fEfDJpC4Q": 0]),

        .init(id: .bootChime, category: .hardware, title: String(localized: "Boot & Shutdown Chime"), detail: String(localized: "Enables the device boot and shutdown chime capability."), values: ["QHxt+hGLaBPbQJbXiUJX3w": 1]),
        .init(id: .chargeLimit, category: .hardware, title: String(localized: "Charge Limit Menu"), detail: String(localized: "Shows the Settings menu; actual limiting depends on hardware."), values: ["37NVydb//GP/GrhuTN+exg": 1]),
        .init(id: .tapToWake, category: .hardware, title: String(localized: "Tap to Wake"), detail: String(localized: "Primarily for models such as iPhone SE where it is unavailable."), values: ["yZf3GTRMGTuwSV/lD7Cagw": 1]),
        .init(id: .cameraButton, category: .settings, title: String(localized: "Camera Control Settings"), detail: String(localized: "Shows Camera Control settings and related capabilities."), values: ["CwvKxM2cEogD3p+HYgaW0Q": 1, "oOV1jhJbdV3AddkcCg0AEA": 1]),
        .init(id: .pencil, category: .settings, title: String(localized: "Apple Pencil Settings"), detail: String(localized: "Shows the Apple Pencil settings page."), values: ["yhHcB0iH0d1XzPO/CFd3ow": 1]),
        .init(id: .actionButton, category: .settings, title: String(localized: "Action Button Settings"), detail: String(localized: "Shows the Action Button settings page."), values: ["cT44WE1EohiwRzhsZ8xEsw": 1]),
        .init(id: .collisionSOS, category: .settings, title: String(localized: "Collision SOS"), detail: String(localized: "Shows collision detection in SOS settings."), values: ["HCzWusHQwZDea6nNhaKndw": 1]),

        .init(id: .stageManager, category: .ipad, title: String(localized: "Stage Manager Support"), detail: String(localized: "Marks the device as supporting Stage Manager."), values: ["qeaj75wk3HF4DwQ8qbIi7g": 1]),
        .init(id: .iPadApps, category: .ipad, title: String(localized: "Allow iPad Apps"), detail: String(localized: "Enables iPad app compatibility types on iPhone."), values: ["9MZ5AdH43csAUajl/dU+IQ": [1, 2]]),
        .init(id: .iPadOS, category: .ipad, title: String(localized: "Enable iPadOS Mode"), detail: String(localized: "Includes multitasking, Stage Manager and iPad app support. Experimental: may cause instability or boot loops. Do not use with an alphanumeric passcode or turn off Show Dock in Stage Manager."), values: ["mG0AnH/Vy1veoqoLRAIgTA": 1, "UCG5MkVahJxG1YULbbd5Bg": 1, "ZYqko/XM5zD3XBfN5RmaXA": 1, "nVh/gwNpy7Jv1NOk00CMrw": 1, "uKc7FPnEO++lVhHWHFlGbQ": 1, "qeaj75wk3HF4DwQ8qbIi7g": 1, "9MZ5AdH43csAUajl/dU+IQ": [1, 2]], isRisky: true),

        .init(id: .internalInstall, category: .internalFeatures, title: String(localized: "Apple Internal Install"), detail: String(localized: "Enables internal capabilities such as Metal HUD; some services may misbehave."), values: ["EqrsVvjcYDdxHBiQmGhAWw": 1], isRisky: true),
        .init(id: .internalStorage, category: .internalFeatures, title: String(localized: "Internal Storage View"), detail: String(localized: "Shows internal files in Storage settings; high risk on some iPads."), values: ["LBJfwOEzExRxzlAnSuI7eg": 1], isRisky: true),
        .init(id: .securityResearchDevice, category: .internalFeatures, title: String(localized: "Security Research Device Mode"), detail: String(localized: "Marks the device as a Security Research Device."), values: ["XYlJKKkj2hztRP1NWWnhlw": 1], isRisky: true)
    ]

    static let iPadIncludedTweaks: Set<GestaltTweakID> = [.stageManager, .iPadApps]

    static func selecting(_ id: GestaltTweakID, enabled: Bool, in selection: Set<GestaltTweakID>) -> Set<GestaltTweakID> {
        var result = selection
        if enabled {
            result.insert(id)
            if id == .iPadOS { result.subtract(iPadIncludedTweaks) }
            if id == .enableLiquidGlassLowPerformance { result.remove(.disableLiquidGlassLowPerformance) }
            if id == .disableLiquidGlassLowPerformance { result.remove(.enableLiquidGlassLowPerformance) }
        } else {
            result.remove(id)
        }
        if result.contains(.iPadOS) { result.subtract(iPadIncludedTweaks) }
        return result
    }

    static func definition(for id: GestaltTweakID) -> GestaltTweakDefinition? {
        definitions.first { $0.id == id }
    }
}

struct DynamicIslandOption: Identifiable, Hashable {
    let subtype: Int
    let title: String
    var id: Int { subtype }

    static let all: [DynamicIslandOption] = [
        .init(subtype: 2436, title: String(localized: "iPhone X Gestures (SE)")),
        .init(subtype: 2556, title: "iPhone 14 Pro"),
        .init(subtype: 2796, title: "iPhone 14 Pro Max"),
        .init(subtype: 2622, title: "iPhone 16 Pro"),
        .init(subtype: 2868, title: "iPhone 16 Pro Max"),
        .init(subtype: 2736, title: "iPhone Air")
    ]
}

enum GestaltTweakError: LocalizedError {
    case artworkDictionaryMissing
    case cacheDataMissing
    case cacheDataTooShort
    case cacheDataPatternNotFound
    case invalidCacheDataOffset
    case unsupportedPreset(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedPreset(let title): String(format: String(localized: "%@ is not available on this system version."), title)
        case .artworkDictionaryMissing: String(localized: "MobileGestalt is missing the ArtworkDevice dictionary, so Dynamic Island or model name cannot be changed.")
        case .cacheDataMissing: String(localized: "MobileGestalt is missing CacheData, so iPadOS mode cannot be enabled.")
        case .cacheDataTooShort: String(localized: "CacheData is too short to apply iPadOS mode safely.")
        case .cacheDataPatternNotFound: String(localized: "The iPadOS marker required by Nugget was not found in CacheData.")
        case .invalidCacheDataOffset: String(localized: "CacheData marker validation failed. No changes were made.")
        }
    }
}

extension GestaltPlist {
    mutating func apply(definition: GestaltTweakDefinition, on version: OperatingSystemVersion = ProcessInfo.processInfo.operatingSystemVersion) throws {
        guard definition.isAvailable(on: version) else {
            throw GestaltTweakError.unsupportedPreset(definition.title)
        }
        if definition.id == .iPadOS {
            try enableIPadOSCacheData()
        }
        for (key, value) in definition.values {
            setCacheExtra(value, forKey: key)
        }
    }

    mutating func setDynamicIslandSubtype(_ subtype: Int) throws {
        let key = "oPeik/9e8lQWMszEjbPzng"
        guard var artwork = cacheExtra[key] as? [String: Any] else {
            throw GestaltTweakError.artworkDictionaryMissing
        }
        artwork["ArtworkDeviceSubType"] = subtype
        setCacheExtra(artwork, forKey: key)
        setCacheExtra(1, forKey: "YlEtTtHlNesRBMal1CqRaA")
    }

    mutating func setModelName(_ name: String) throws {
        let key = "oPeik/9e8lQWMszEjbPzng"
        guard var artwork = cacheExtra[key] as? [String: Any] else {
            throw GestaltTweakError.artworkDictionaryMissing
        }
        artwork["ArtworkDeviceProductDescription"] = name
        setCacheExtra(artwork, forKey: key)
    }

    private mutating func enableIPadOSCacheData() throws {
        guard let cacheData = dict["CacheData"] as? Data else {
            throw GestaltTweakError.cacheDataMissing
        }
        var hex = Array(cacheData.map { String(format: "%02x", $0) }.joined())
        let sliceStart = 1616
        let sliceLength = 200
        guard hex.count > sliceStart else { throw GestaltTweakError.cacheDataTooShort }

        let end = min(hex.count, sliceStart + sliceLength)
        let slice = String(hex[sliceStart..<end])
        let regex = try NSRegularExpression(pattern: "0+(?:5555)*([0-9a-f]{4})")
        let nsRange = NSRange(slice.startIndex..<slice.endIndex, in: slice)
        var matchedOffset: Int?
        regex.enumerateMatches(in: slice, range: nsRange) { match, _, stop in
            guard let range = match.flatMap({ Range($0.range(at: 1), in: slice) }) else { return }
            let value = slice[range]
            if value.filter({ $0 != "0" }).count >= 3 {
                matchedOffset = sliceStart + slice.distance(from: slice.startIndex, to: range.lowerBound)
                stop.pointee = true
            }
        }
        guard let offset = matchedOffset else { throw GestaltTweakError.cacheDataPatternNotFound }

        let rightOffset = offset + 13
        let leftOffset = offset - 67
        guard leftOffset > 0, rightOffset < hex.count - 1 else {
            throw GestaltTweakError.invalidCacheDataOffset
        }
        for position in [leftOffset, rightOffset] {
            guard ["1", "3"].contains(String(hex[position])),
                  hex[position - 1] == "0", hex[position + 1] == "0" else {
                throw GestaltTweakError.invalidCacheDataOffset
            }
        }
        hex[leftOffset] = "3"
        let updatedHex = String(hex)
        var updatedData = Data(capacity: updatedHex.count / 2)
        var index = updatedHex.startIndex
        while index < updatedHex.endIndex {
            let next = updatedHex.index(index, offsetBy: 2)
            guard let byte = UInt8(updatedHex[index..<next], radix: 16) else {
                throw GestaltTweakError.invalidCacheDataOffset
            }
            updatedData.append(byte)
            index = next
        }
        dict["CacheData"] = updatedData
    }
}

struct GestaltRegionPreset: Identifiable {
    let code: String
    let title: String
    var id: String { code }
    var salesCode: String { code + "/A" }

    static let all: [Self] = [
        .init(code: "LL", title: String(localized: "United States")),
        .init(code: "ZA", title: String(localized: "Hong Kong")),
        .init(code: "J", title: String(localized: "Japan")),
        .init(code: "CH", title: String(localized: "China Mainland")),
        .init(code: "TA", title: String(localized: "Taiwan")),
        .init(code: "B", title: String(localized: "United Kingdom")),
        .init(code: "C", title: String(localized: "Canada"))
    ]
}

extension GestaltPlist {
    mutating func apply(region: GestaltRegionPreset) {
        setCacheExtra(region.code, forKey: "h63QSdBCiT/z0WU6rdQv6Q")
        setCacheExtra(region.salesCode, forKey: "yK+xavymRGZ3xWc1tb8XDg")
    }
}
