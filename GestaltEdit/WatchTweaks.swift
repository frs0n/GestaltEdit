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
        .init(id: "appleIntelligence", title: String(localized: "Apple Intelligence Capability"), group: .intelligence, keys: ["A62OafQ85EJAiiqKn4agtg"]),
        .init(id: "onDeviceSiri", title: String(localized: "On-Device Siri"), group: .intelligence, keys: ["K/R1GfGfCkXvEhaPS2Vrng"]),
        .init(id: "audioIntelligence", title: String(localized: "Audio Intelligence"), group: .intelligence, keys: ["rb2tKZxlj0Gm2tBmUQSLqQ"])
    ]

    static let regions = [("United States", "LL", "LL/A"), ("Hong Kong", "ZA", "ZA/A"),
                          ("Japan", "J", "J/A"), ("China (Mainland)", "CH", "CH/A"),
                          ("Taiwan", "TA", "TA/A"), ("United Kingdom", "B", "B/A"), ("Canada", "C", "C/A")]
    static let resolutions = [("SE · 40 mm", 324, 394), ("SE · 44 mm", 368, 448),
                              ("S7–S9 · 41 mm", 352, 430), ("S7–S9 · 45 mm", 396, 484),
                              ("S10–S12 · 42 mm", 374, 446), ("S10–S12 · 46 mm", 416, 496)]

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

    static func apply(_ identifiers: Set<String>, to plist: GestaltPlist, build: String, directory: URL? = nil) throws -> GestaltPlist {
        var result = plist
        for id in identifiers.sorted() {
            guard let definition = definitions.first(where: { $0.id == id }) else { throw WatchMGWire.failure("Unknown Watch preset.") }
            if !definition.isFace {
                for key in definition.keys { result.setCacheExtra(true, forKey: key) }
                continue
            }
            guard let layout = faceLayout(plist: result, build: build, directory: directory),
                  let defaults = resource("WatchMGDefaults", directory: directory)[build] as? [String: Any],
                  let offset = layout[id == "hermes" ? "DeviceBrandOffset" : "ScreenClassOffset"] as? Int,
                  let value = defaults[id == "hermes" ? "HermesEnabledDeviceBrand" : "UltraEnabledScreenClass"] as? UInt32,
                  var data = result.dict["CacheData"] as? Data else {
                throw WatchMGWire.failure(String(localized: "Watch face changes are unavailable on this watchOS build. No changes were written."))
            }
            for byte in 0..<4 { data[offset + byte] = UInt8(truncatingIfNeeded: value >> (byte * 8)) }
            result.dict["CacheData"] = data
            var extra = result.cacheExtra
            extra.removeValue(forKey: id == "hermes" ? "fuKL2rMywRgQF1wowOA/cg" : "fdh+s6j3VijuyrK7xLjd7g")
            result.dict["CacheExtra"] = extra
        }
        return result
    }
}
