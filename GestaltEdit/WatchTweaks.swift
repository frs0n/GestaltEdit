import Foundation

// watchOS keys and build layouts adapted from pookjw/HermesEnabler (MIT).
// See Shared/HermesEnabler-LICENSE.txt. iOS presets never enter this catalog.
enum WatchTweakGroup: String, CaseIterable, Identifiable {
    case faces, display, controls, sensors, voice, intelligence
    var id: Self { self }
    var title: String {
        switch self {
        case .faces: String(localized: "Watch Faces")
        case .display: String(localized: "Watch Display")
        case .controls: String(localized: "Watch Controls")
        case .sensors: String(localized: "Sensors & Workouts")
        case .voice: String(localized: "Watch Voice")
        case .intelligence: String(localized: "Watch Intelligence")
        }
    }
}

struct WatchTweak: Identifiable {
    let id: String
    let title: String
    let group: WatchTweakGroup
    let keys: [String]
    var isFace: Bool { group == .faces }
}

enum WatchTweakCatalog {
    static let definitions: [WatchTweak] = [
        .init(id: "hermes", title: "Hermès", group: .faces, keys: []),
        .init(id: "ultra", title: String(localized: "Ultra Watch Faces"), group: .faces, keys: []),
        .init(id: "aod", title: String(localized: "Always-On Display"), group: .display, keys: ["2OOJf1VhaM7NxfRok3HbWQ", "j8/Omm6s1lsmTDFsXjsBfA"]),
        .init(id: "aodSeconds", title: String(localized: "AOD 1 Hz"), group: .display, keys: ["aoJSd/MXk7M40NgXTM6x+g"]),
        .init(id: "aodVibrancy", title: String(localized: "AOD Vibrancy"), group: .display, keys: ["ykpu7qyhqFweVMKtxNylWA"]),
        .init(id: "ambientLight", title: String(localized: "Periodic Ambient Light Updates"), group: .display, keys: ["Leuy56dCZmAMYoVCQGTfPA"]),
        .init(id: "actionButton", title: String(localized: "Watch Action Button"), group: .controls, keys: ["FBw/2WrPE2supEKosxxoTw"]),
        .init(id: "doubleTap", title: String(localized: "Double Tap"), group: .controls, keys: ["l1CWke97nbaAcWDqA6T5LA"]),
        .init(id: "keyboard", title: String(localized: "On-Screen Keyboard"), group: .controls, keys: ["MQJ1mlVrhOwaUUVJehJSVA"]),
        .init(id: "wristWake", title: String(localized: "Raise Wrist to Wake"), group: .controls, keys: ["nmOy2K5HzAAs2QNAi8wR+Q"]),
        .init(id: "depth", title: String(localized: "Depth Sensor"), group: .sensors, keys: ["Ijs+pw5tRyxqSy5kfgZNuQ"]),
        .init(id: "altimeter", title: String(localized: "Absolute Altimeter"), group: .sensors, keys: ["PFnuFyqMMnGUQQnTqS5byg"]),
        .init(id: "compass", title: String(localized: "Always-On Compass"), group: .sensors, keys: ["aCQx2Qq/TChnNAq1rr6Egw"]),
        .init(id: "orienteering", title: String(localized: "Compass Orienteering"), group: .sensors, keys: ["GPIs61LYNpcwZqwlFr7bbg"]),
        .init(id: "heartRate", title: String(localized: "Continuous Heart Rate"), group: .sensors, keys: ["W2RPjaqovtsgiRB6ScePGA"]),
        .init(id: "noise", title: String(localized: "Noise Exposure"), group: .sensors, keys: ["SaW+DA+cbiqDHrex8MTABA"]),
        .init(id: "battery", title: String(localized: "Battery Information"), group: .sensors, keys: ["Kao6GNYdAy5hwXblxeGYJQ"]),
        .init(id: "swimming", title: String(localized: "Swimming Workouts"), group: .sensors, keys: ["cRjPy4Ef+KZwJ+nfPeBV5Q"]),
        .init(id: "raiseToSpeak", title: String(localized: "Raise to Speak"), group: .voice, keys: ["4D8XW4YwJI7QvyPhv1TEdw"]),
        .init(id: "siriListening", title: String(localized: "Siri Listening Capability"), group: .voice, keys: ["U+73bmG4kBGj6kpreQXUTQ"]),
        .init(id: "intelligence", title: String(localized: "Enable Siri AI"), group: .intelligence,
              keys: ["A62OafQ85EJAiiqKn4agtg", "K/R1GfGfCkXvEhaPS2Vrng", "rb2tKZxlj0Gm2tBmUQSLqQ"])
    ]

    static let regions = [("United States", "LL", "LL/A"), ("Hong Kong", "ZA", "ZA/A"),
                          ("Japan", "J", "J/A"), ("China (Mainland)", "CH", "CH/A"),
                          ("Taiwan", "TA", "TA/A"), ("United Kingdom", "B", "B/A"), ("Canada", "C", "C/A")]
    static let resolutions = [("SE · 40 mm", 324, 394), ("SE · 44 mm", 368, 448),
                              ("S7–S9 · 41 mm", 352, 430), ("S7–S9 · 45 mm", 396, 484),
                              ("S10–S12 · 42 mm", 374, 446), ("S10–S12 · 46 mm", 416, 496)]

    // Siri AI is unavailable on watchOS in the EU and mainland China.
    // Source: https://support.apple.com/en-us/127893 (2026-11-15).
    // Use the Watch's regional setting, not the paired iPhone's locale or GPS.
    private static let unsupportedIntelligenceRegions: Set<String> = [
        "CN", "AT", "BE", "BG", "HR", "CY", "CZ", "DK", "EE", "FI", "FR", "DE",
        "GR", "HU", "IE", "IT", "LV", "LT", "LU", "MT", "NL", "PL", "PT", "RO", "SK", "SI", "ES", "SE"
    ]

    static func needsIntelligenceRegionChange(plist: GestaltPlist, regionIdentifier: String) -> Bool {
        if unsupportedIntelligenceRegions.contains(regionIdentifier.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()) { return true }
        // Also recognize mainland-China MG region/sales markers, including
        // older helpers that do not yet report their regional setting.
        return ["h63QSdBCiT/z0WU6rdQv6Q", "zHeENZu+wbg7PUprwNwBWg", "yK+xavymRGZ3xWc1tb8XDg"].contains { key in
            guard let value = plist.cacheExtra[key] as? String else { return false }
            return value.trimmingCharacters(in: .whitespacesAndNewlines).uppercased().split(separator: "/").first == "CH"
        }
    }

    private static func adjustIntelligenceRegion(_ plist: inout GestaltPlist, regionIdentifier: String) {
        guard needsIntelligenceRegionChange(plist: plist, regionIdentifier: regionIdentifier) else { return }
        plist.setCacheExtra("LL", forKey: "h63QSdBCiT/z0WU6rdQv6Q")
        let current = "zHeENZu+wbg7PUprwNwBWg", legacy = "yK+xavymRGZ3xWc1tb8XDg"
        let hasCurrent = plist.cacheExtra[current] != nil, hasLegacy = plist.cacheExtra[legacy] != nil
        if hasCurrent || !hasLegacy { plist.setCacheExtra("LL/A", forKey: current) }
        if hasLegacy { plist.setCacheExtra("LL/A", forKey: legacy) }
    }

    static func resource(_ name: String, directory: URL? = nil) -> [String: Any] {
        let url = directory?.appendingPathComponent(name + ".plist") ?? Bundle.main.url(forResource: name, withExtension: "plist")
        guard let url, let data = try? Data(contentsOf: url),
              let root = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] else { return [:] }
        return root["Builds"] as? [String: Any] ?? [:]
    }

    // Validate the *watch's* reported build and cache, never the iPhone's OS.
    static func faceLayout(plist: GestaltPlist, build: String, directory: URL? = nil) -> [String: Any]? {
        guard let layout = resource("WatchMGOffsets", directory: directory)[build] as? [String: Any],
              let expectedUUID = layout["CacheUUID"] as? String,
              plist.dict["CacheUUID"] as? String == expectedUUID,
              let count = layout["CacheDataLength"] as? Int,
              let data = plist.dict["CacheData"] as? Data, data.count == count,
              let brand = layout["DeviceBrandOffset"] as? Int, brand >= 0, brand <= count - 4,
              let brandPresent = layout["DeviceBrandPresentOffset"] as? Int, data.indices.contains(brandPresent),
              let screen = layout["ScreenClassOffset"] as? Int, screen >= 0, screen <= count - 4,
              let screenPresent = layout["ScreenClassPresentOffset"] as? Int, data.indices.contains(screenPresent),
              data[brandPresent] == 1, data[screenPresent] == 1 else { return nil }
        return layout
    }

    static func ultraFaceClasses(plist: GestaltPlist, build: String, directory: URL? = nil) -> [Int] {
        guard faceLayout(plist: plist, build: build, directory: directory) != nil,
              let defaults = resource("WatchMGDefaults", directory: directory)[build] as? [String: Any],
              let options = defaults["UltraScreenClassOptions"] as? [Int],
              !options.isEmpty, options.allSatisfy({ [29, 38].contains($0) }) else { return [] }
        return options
    }

    static func currentUltraFaceClass(plist: GestaltPlist, build: String, directory: URL? = nil) -> Int? {
        guard let layout = faceLayout(plist: plist, build: build, directory: directory),
              let offset = layout["ScreenClassOffset"] as? Int,
              let data = plist.dict["CacheData"] as? Data,
              plist.cacheExtra["fdh+s6j3VijuyrK7xLjd7g"] == nil else { return nil }
        let value = integer(in: data, offset: offset)
        return ultraFaceClasses(plist: plist, build: build, directory: directory).contains(value) ? value : nil
    }

    private static func integer(in data: Data, offset: Int) -> Int {
        (0..<4).reduce(0) { $0 | (Int(data[offset + $1]) << ($1 * 8)) }
    }

    private static func validateUltraClass(_ value: Int, current: GestaltPlist, original: GestaltPlist?,
                                           build: String, hardwareIdentifier: String, directory: URL?) throws {
        let error = WatchMGWire.failure(String(localized: "The selected Ultra face layout is unavailable or the original Watch cache could not be verified. No changes were written."))
        guard ultraFaceClasses(plist: current, build: build, directory: directory).contains(value),
              let layout = faceLayout(plist: current, build: build, directory: directory),
              let defaults = resource("WatchMGDefaults", directory: directory)[build] as? [String: Any],
              let defaultClass = defaults["UltraEnabledScreenClass"] as? Int,
              let offset = layout["ScreenClassOffset"] as? Int,
              let data = current.dict["CacheData"] as? Data else { throw error }
        let currentClass = integer(in: data, offset: offset)
        let options = ultraFaceClasses(plist: current, build: build, directory: directory)
        // Match HermesEnabler's extra checks for class 38 and switching back
        // from it. A default class-29 enable retains the existing behavior.
        guard value != defaultClass || (currentClass != defaultClass && options.contains(currentClass)) else { return }
        guard !hardwareIdentifier.isEmpty,
              let original, faceLayout(plist: original, build: build, directory: directory) != nil,
              let originalData = original.dict["CacheData"] as? Data,
              current.cacheExtra["fdh+s6j3VijuyrK7xLjd7g"] == nil,
              original.cacheExtra["fdh+s6j3VijuyrK7xLjd7g"] == nil else { throw error }
        let originalClass = integer(in: originalData, offset: offset)
        let models = defaults["ModelValidation"] as? [String: Any]
        let model = models?[hardwareIdentifier] as? [String: Any]
        let expectedOriginal = model?["ExpectedOriginalScreenClass"] as? Int ?? originalClass
        guard originalClass == expectedOriginal,
              currentClass == expectedOriginal || currentClass == value || options.contains(currentClass) else { throw error }
    }

    static func apply(_ identifiers: Set<String>, to plist: GestaltPlist, build: String, regionIdentifier: String = "", ultraFaceClass: Int? = nil, original: GestaltPlist? = nil, hardwareIdentifier: String = "", directory: URL? = nil) throws -> GestaltPlist {
        var result = plist
        for id in identifiers.sorted() {
            guard let definition = definitions.first(where: { $0.id == id }) else { throw WatchMGWire.failure("Unknown Watch preset.") }
            if !definition.isFace {
                for key in definition.keys { result.setCacheExtra(true, forKey: key) }
                if id == "intelligence" { adjustIntelligenceRegion(&result, regionIdentifier: regionIdentifier) }
                continue
            }
            guard let layout = faceLayout(plist: result, build: build, directory: directory),
                  let defaults = resource("WatchMGDefaults", directory: directory)[build] as? [String: Any],
                  let offset = layout[id == "hermes" ? "DeviceBrandOffset" : "ScreenClassOffset"] as? Int,
                  let value = defaults[id == "hermes" ? "HermesEnabledDeviceBrand" : "UltraEnabledScreenClass"] as? UInt32,
                  var data = result.dict["CacheData"] as? Data else {
                throw WatchMGWire.failure(String(localized: "Watch face changes are unavailable on this watchOS build. No changes were written."))
            }
            var requestedValue = value
            if id == "ultra" {
                let selected = ultraFaceClass ?? Int(value)
                try validateUltraClass(selected, current: result, original: original, build: build,
                                       hardwareIdentifier: hardwareIdentifier, directory: directory)
                requestedValue = UInt32(selected)
            }
            for byte in 0..<4 { data[offset + byte] = UInt8(truncatingIfNeeded: requestedValue >> (byte * 8)) }
            result.dict["CacheData"] = data
            var extra = result.cacheExtra
            extra.removeValue(forKey: id == "hermes" ? "fuKL2rMywRgQF1wowOA/cg" : "fdh+s6j3VijuyrK7xLjd7g")
            result.dict["CacheExtra"] = extra
        }
        return result
    }
}
