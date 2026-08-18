import Foundation

enum GestaltTweakCategory: String, CaseIterable, Identifiable {
    case region
    case display
    case hardware
    case ipad
    case internalFeatures

    var id: String { rawValue }

    var label: String {
        switch self {
        case .display: String(localized: "Display & Appearance")
        case .hardware: String(localized: "Hardware Capabilities")
        case .ipad: String(localized: "iPad Capabilities")
        case .region: String(localized: "Region")
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

    var id: String { rawValue }
}

struct GestaltTweakDefinition: Identifiable {
    let id: GestaltTweakID
    let category: GestaltTweakCategory
    let title: String
    let detail: String
    let values: [String: Any]
    var isRisky = false
}

enum GestaltTweakCatalog {
    static let definitions: [GestaltTweakDefinition] = [
        .init(id: .supportsDynamicIsland, category: .display, title: String(localized: "Enable Dynamic Island Capability"), detail: String(localized: "Nugget's alternate enable method."), values: ["YlEtTtHlNesRBMal1CqRaA": 1]),
        .init(id: .alwaysOnDisplay, category: .display, title: String(localized: "Always-On Display"), detail: String(localized: "May increase burn-in risk on unsupported devices."), values: ["2OOJf1VhaM7NxfRok3HbWQ": 1, "j8/Omm6s1lsmTDFsXjsBfA": 1], isRisky: true),
        .init(id: .alwaysOnDisplayVibrancy, category: .display, title: String(localized: "AOD Vibrancy"), detail: String(localized: "Use this when AOD rendering looks incorrect."), values: ["ykpu7qyhqFweVMKtxNylWA": 1]),
        .init(id: .disableParallax, category: .display, title: String(localized: "Disable Wallpaper Parallax"), detail: String(localized: "Stops wallpaper motion based on device movement."), values: ["UIParallaxCapability": 0]),
        .init(id: .enableLiquidGlassLowPerformance, category: .display, title: String(localized: "Enable Liquid Glass Low-Performance Mode"), detail: String(localized: "For iOS 26 and later."), values: ["SAGvsp6O6kAQ4fEfDJpC4Q": 1]),
        .init(id: .disableLiquidGlassLowPerformance, category: .display, title: String(localized: "Disable Liquid Glass Low-Performance Mode"), detail: String(localized: "Mutually exclusive with the option above."), values: ["SAGvsp6O6kAQ4fEfDJpC4Q": 0]),

        .init(id: .bootChime, category: .hardware, title: String(localized: "Boot & Shutdown Chime"), detail: String(localized: "Enables the device boot and shutdown chime capability."), values: ["QHxt+hGLaBPbQJbXiUJX3w": 1]),
        .init(id: .chargeLimit, category: .hardware, title: String(localized: "Charge Limit Menu"), detail: String(localized: "Shows the Settings menu; actual limiting depends on hardware."), values: ["37NVydb//GP/GrhuTN+exg": 1]),
        .init(id: .tapToWake, category: .hardware, title: String(localized: "Tap to Wake"), detail: String(localized: "Primarily for models such as iPhone SE where it is unavailable."), values: ["yZf3GTRMGTuwSV/lD7Cagw": 1]),
        .init(id: .cameraButton, category: .hardware, title: String(localized: "iPhone 16 Camera Control Settings"), detail: String(localized: "Shows Camera Control settings and related capabilities."), values: ["CwvKxM2cEogD3p+HYgaW0Q": 1, "oOV1jhJbdV3AddkcCg0AEA": 1]),
        .init(id: .pencil, category: .hardware, title: String(localized: "Apple Pencil Settings"), detail: String(localized: "Shows the Apple Pencil settings page."), values: ["yhHcB0iH0d1XzPO/CFd3ow": 1]),
        .init(id: .actionButton, category: .hardware, title: String(localized: "Action Button Settings"), detail: String(localized: "Shows the Action Button settings page."), values: ["cT44WE1EohiwRzhsZ8xEsw": 1]),
        .init(id: .collisionSOS, category: .hardware, title: String(localized: "Collision SOS"), detail: String(localized: "Shows collision detection in SOS settings."), values: ["HCzWusHQwZDea6nNhaKndw": 1]),

        .init(id: .stageManager, category: .ipad, title: String(localized: "Stage Manager Support"), detail: String(localized: "Marks the device as supporting Stage Manager."), values: ["qeaj75wk3HF4DwQ8qbIi7g": 1]),
        .init(id: .iPadApps, category: .ipad, title: String(localized: "Allow iPad Apps"), detail: String(localized: "Enables iPad app compatibility types on iPhone."), values: ["9MZ5AdH43csAUajl/dU+IQ": [1, 2]]),
        .init(id: .iPadOS, category: .ipad, title: String(localized: "Enable iPadOS Mode"), detail: String(localized: "Changes five capabilities and CacheData; experimental and high risk."), values: ["mG0AnH/Vy1veoqoLRAIgTA": 1, "UCG5MkVahJxG1YULbbd5Bg": 1, "ZYqko/XM5zD3XBfN5RmaXA": 1, "nVh/gwNpy7Jv1NOk00CMrw": 1, "uKc7FPnEO++lVhHWHFlGbQ": 1], isRisky: true),

        .init(id: .internalInstall, category: .internalFeatures, title: String(localized: "Apple Internal Install"), detail: String(localized: "Enables internal capabilities such as Metal HUD; some services may misbehave."), values: ["EqrsVvjcYDdxHBiQmGhAWw": 1], isRisky: true),
        .init(id: .internalStorage, category: .internalFeatures, title: String(localized: "Internal Storage View"), detail: String(localized: "Shows internal files in Storage settings; high risk on some iPads."), values: ["LBJfwOEzExRxzlAnSuI7eg": 1], isRisky: true),
        .init(id: .securityResearchDevice, category: .internalFeatures, title: String(localized: "Security Research Device Mode"), detail: String(localized: "Marks the device as a Security Research Device."), values: ["XYlJKKkj2hztRP1NWWnhlw": 1], isRisky: true)
    ]

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

    var errorDescription: String? {
        switch self {
        case .artworkDictionaryMissing: String(localized: "MobileGestalt is missing the ArtworkDevice dictionary, so Dynamic Island or model name cannot be changed.")
        case .cacheDataMissing: String(localized: "MobileGestalt is missing CacheData, so iPadOS mode cannot be enabled.")
        case .cacheDataTooShort: String(localized: "CacheData is too short to apply iPadOS mode safely.")
        case .cacheDataPatternNotFound: String(localized: "The iPadOS marker required by Nugget was not found in CacheData.")
        case .invalidCacheDataOffset: String(localized: "CacheData marker validation failed. No changes were made.")
        }
    }
}

extension GestaltPlist {
    /// Checks whether every value in ``definition`` already matches the
    /// corresponding ``CacheExtra`` entry, i.e. the tweak is already applied.
    func isTweakApplied(_ definition: GestaltTweakDefinition) -> Bool {
        let cacheExtra = self.cacheExtra
        for (key, value) in definition.values {
            guard let stored = cacheExtra[key] else { return false }
            if !Self.valuesMatch(stored, value) { return false }
        }
        return true
    }

    private static func valuesMatch(_ stored: Any, _ expected: Any) -> Bool {
        if let expectedArray = expected as? [Any] {
            guard let storedArray = stored as? [Any] else { return false }
            return expectedArray.allSatisfy { expectedItem in
                storedArray.contains { storedItem in
                    valuesMatch(storedItem, expectedItem)
                }
            }
        }
        if let storedNum = stored as? NSNumber, let expectedNum = expected as? NSNumber {
            return storedNum.int64Value == expectedNum.int64Value
        }
        if let storedStr = stored as? String, let expectedStr = expected as? String {
            return storedStr == expectedStr
        }
        return false
    }

    mutating func apply(definition: GestaltTweakDefinition) throws {
        for (key, value) in definition.values {
            setCacheExtra(value, forKey: key)
        }
        if definition.id == .iPadOS {
            try enableIPadOSCacheData()
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
