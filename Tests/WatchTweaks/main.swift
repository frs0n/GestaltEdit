import Foundation

let resources = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let build = "24S118"
let layout = WatchTweakCatalog.resource("WatchMGOffsets", directory: resources)[build] as! [String: Any]
var bytes = Data(repeating: 0x44, count: 6480)
bytes[5865] = 1
bytes[6230] = 1
bytes.replaceSubrange(840..<844, with: [0, 0, 0, 0])
bytes.replaceSubrange(3760..<3764, with: [35, 0, 0, 0])
let original = GestaltPlist(dict: ["CacheData": bytes,
    "CacheUUID": "32B4CA84-FBDA-496C-9B79-2101D597158B",
    "CacheExtra": ["fuKL2rMywRgQF1wowOA/cg": 0, "fdh+s6j3VijuyrK7xLjd7g": 35, "unrelated": "keep"]])
let changed = try WatchTweakCatalog.apply(["hermes", "ultra", "actionButton", "doubleTap", "keyboard", "intelligence"], to: original, build: build, directory: resources)
let data = changed.dict["CacheData"] as! Data
var expected = bytes
expected[840] = 1
expected[3760] = 29
precondition(data == expected, "Face changes must alter only the intended 32-bit slots")
precondition(data[5865] == 1 && data[6230] == 1)
precondition(changed.cacheExtra["fuKL2rMywRgQF1wowOA/cg"] == nil)
precondition(changed.cacheExtra["fdh+s6j3VijuyrK7xLjd7g"] == nil)
for key in ["FBw/2WrPE2supEKosxxoTw", "l1CWke97nbaAcWDqA6T5LA", "MQJ1mlVrhOwaUUVJehJSVA", "K/R1GfGfCkXvEhaPS2Vrng"] {
    precondition(changed.cacheExtra[key] as? Bool == true)
}
precondition(changed.cacheExtra["cT44WE1EohiwRzhsZ8xEsw"] == nil)
for key in ["YlEtTtHlNesRBMal1CqRaA", "qeaj75wk3HF4DwQ8qbIi7g", "a3n5T9sFtlyQ74NEp9ESxg", "97JDvERpVwO+GHtthIh7hA"] {
    precondition(changed.cacheExtra[key] == nil, "Watch presets must not apply iPhone/iPad fields")
}
precondition(changed.cacheExtra["unrelated"] as? String == "keep")
precondition(original.dict["CacheData"] as! Data == bytes)
func rejected(_ plist: GestaltPlist, build: String = build) {
    do {
        _ = try WatchTweakCatalog.apply(["hermes"], to: plist, build: build, directory: resources)
        fatalError("Unverified Watch layout was accepted")
    } catch {}
}
rejected(original, build: "unknown-watch-build")
var wrong = original
wrong.dict["CacheUUID"] = UUID().uuidString
rejected(wrong)
wrong = original
wrong.dict["CacheData"] = Data(repeating: 0, count: 100)
rejected(wrong)
wrong = original
var absent = bytes
absent[5865] = 0
wrong.dict["CacheData"] = absent
rejected(wrong)
for (name, entry) in WatchTweakCatalog.resource("WatchMGOffsets", directory: resources) {
    let layout = entry as! [String: Any]
    let count = layout["CacheDataLength"] as! Int
    var synthetic = Data(repeating: 0, count: count)
    synthetic[layout["DeviceBrandPresentOffset"] as! Int] = 1
    synthetic[layout["ScreenClassPresentOffset"] as! Int] = 1
    let plist = GestaltPlist(dict: ["CacheData": synthetic, "CacheUUID": layout["CacheUUID"]!, "CacheExtra": [:]])
    _ = try WatchTweakCatalog.apply(["hermes", "ultra"], to: plist, build: name, directory: resources)
}
print("Passed: all reference Watch layouts; Hermès/Ultra golden bytes; Watch-specific controls; preservation of unrelated data; unknown build, UUID, length and presence rejection; no iPhone/iPad preset leakage.")

let regionKey = "h63QSdBCiT/z0WU6rdQv6Q"
let currentSales = "zHeENZu+wbg7PUprwNwBWg"
let legacySales = "yK+xavymRGZ3xWc1tb8XDg"
let intelligenceKeys = ["A62OafQ85EJAiiqKn4agtg", "K/R1GfGfCkXvEhaPS2Vrng", "rb2tKZxlj0Gm2tBmUQSLqQ"]
precondition(WatchTweakCatalog.definitions.filter { $0.group == .intelligence }.map(\.id) == ["intelligence"])
for region in ["CN", "AT", "BE", "BG", "HR", "CY", "CZ", "DK", "EE", "FI", "FR", "DE", "GR", "HU", "IE", "IT", "LV", "LT", "LU", "MT", "NL", "PL", "PT", "RO", "SK", "SI", "ES", "SE", " cn "] {
    var source = original
    source.setCacheExtra("D", forKey: regionKey)
    source.setCacheExtra("D/A", forKey: currentSales)
    source.setCacheExtra("D/A", forKey: legacySales)
    let output = try WatchTweakCatalog.apply(["intelligence"], to: source, build: "", regionIdentifier: region)
    precondition(output.cacheExtra[regionKey] as? String == "LL")
    precondition(output.cacheExtra[currentSales] as? String == "LL/A")
    precondition(output.cacheExtra[legacySales] as? String == "LL/A")
    for key in intelligenceKeys { precondition(output.cacheExtra[key] as? Bool == true) }
    precondition(output.dict["CacheData"] as! Data == bytes)
    precondition(output.cacheExtra["h9jDsbgj7xIVeIQ8S3/X3Q"] == nil)
    precondition(output.cacheExtra["a3n5T9sFtlyQ74NEp9ESxg"] == nil)
}
for region in ["US", "GB", "HK", "MO", "TW", "JP", "CA", "", "UNKNOWN"] {
    var source = original
    source.setCacheExtra("J", forKey: regionKey)
    source.setCacheExtra("J/A", forKey: legacySales)
    let output = try WatchTweakCatalog.apply(["intelligence"], to: source, build: "", regionIdentifier: region)
    var expected = source
    for key in intelligenceKeys { expected.setCacheExtra(true, forKey: key) }
    precondition(NSDictionary(dictionary: output.dict).isEqual(to: expected.dict), "Supported/unknown regions must be preserved")
}
// Detect CH in either generation of sales field, even if a helper lacks locale metadata.
for marker in [regionKey, currentSales, legacySales] {
    var source = original
    source.setCacheExtra(marker == regionKey ? "CH" : "CH/A", forKey: marker)
    let output = try WatchTweakCatalog.apply(["intelligence"], to: source, build: "", regionIdentifier: "US")
    precondition(output.cacheExtra[regionKey] as? String == "LL")
    precondition(output.cacheExtra[marker == legacySales ? legacySales : currentSales] as? String == "LL/A")
    if marker == legacySales { precondition(output.cacheExtra[currentSales] == nil) }
}
// The region correction is part of the AI preset only, never an unrelated Watch toggle.
var china = original
china.setCacheExtra("CH", forKey: regionKey)
let unchangedRegion = try WatchTweakCatalog.apply(["keyboard"], to: china, build: "", regionIdentifier: "CN")
precondition(unchangedRegion.cacheExtra[regionKey] as? String == "CH")
print("Passed: combined AI flags, mainland China and all EU regional settings, existing MG China markers, supported/unknown-region preservation, legacy/current sales fields, no device identity spoofing or iPhone SiriMode changes.")

var nativeOriginal = original
nativeOriginal.cacheExtra.removeValue(forKey: "fdh+s6j3VijuyrK7xLjd7g")
let larger = try WatchTweakCatalog.apply(["ultra"], to: nativeOriginal, build: build, ultraFaceClass: 38,
                                        original: nativeOriginal, hardwareIdentifier: "Watch7,18", directory: resources)
var expectedLarge = bytes
expectedLarge[3760] = 38
precondition(larger.dict["CacheData"] as! Data == expectedLarge)
precondition(WatchTweakCatalog.currentUltraFaceClass(plist: larger, build: build, directory: resources) == 38)
let smaller = try WatchTweakCatalog.apply(["ultra"], to: larger, build: build, ultraFaceClass: 29,
                                         original: nativeOriginal, hardwareIdentifier: "Watch7,18", directory: resources)
var expectedSmall = bytes
expectedSmall[3760] = 29
precondition(smaller.dict["CacheData"] as! Data == expectedSmall)
func rejectedLayout(_ current: GestaltPlist, build: String = build, selected: Int = 38,
                    original baseline: GestaltPlist? = nativeOriginal, hardware: String = "Watch7,18") {
    do {
        _ = try WatchTweakCatalog.apply(["ultra"], to: current, build: build, ultraFaceClass: selected,
                                       original: baseline, hardwareIdentifier: hardware, directory: resources)
        fatalError("Unsafe Ultra layout was accepted")
    } catch {}
}
rejectedLayout(nativeOriginal, selected: 40)
rejectedLayout(nativeOriginal, original: nil)
rejectedLayout(nativeOriginal, hardware: "")
var overridden = nativeOriginal
overridden.setCacheExtra(35, forKey: "fdh+s6j3VijuyrK7xLjd7g")
rejectedLayout(overridden)
rejectedLayout(nativeOriginal, original: overridden)
var unexpected = nativeOriginal
var unexpectedData = bytes
unexpectedData[3760] = 99
unexpected.dict["CacheData"] = unexpectedData
rejectedLayout(unexpected)
for (name, entry) in WatchTweakCatalog.resource("WatchMGOffsets", directory: resources) {
    let layout = entry as! [String: Any]
    var data = Data(repeating: 0, count: layout["CacheDataLength"] as! Int)
    data[layout["DeviceBrandPresentOffset"] as! Int] = 1
    data[layout["ScreenClassPresentOffset"] as! Int] = 1
    data[layout["ScreenClassOffset"] as! Int] = 35
    let cache = GestaltPlist(dict: ["CacheData": data, "CacheUUID": layout["CacheUUID"]!, "CacheExtra": [:]])
    let options = WatchTweakCatalog.ultraFaceClasses(plist: cache, build: name, directory: resources)
    if options.contains(38) {
        let result = try WatchTweakCatalog.apply(["ultra"], to: cache, build: name, ultraFaceClass: 38,
                                                original: cache, hardwareIdentifier: "Watch7,18", directory: resources)
        precondition(WatchTweakCatalog.currentUltraFaceClass(plist: result, build: name, directory: resources) == 38)
    } else {
        rejectedLayout(cache, build: name, original: cache)
    }
}
// Build-specific hardware checks from the reference must not be bypassed.
let guardedBuild = "24S5284h"
let guardedLayout = WatchTweakCatalog.resource("WatchMGOffsets", directory: resources)[guardedBuild] as! [String: Any]
var guardedData = Data(repeating: 0, count: guardedLayout["CacheDataLength"] as! Int)
guardedData[guardedLayout["DeviceBrandPresentOffset"] as! Int] = 1
guardedData[guardedLayout["ScreenClassPresentOffset"] as! Int] = 1
guardedData[guardedLayout["ScreenClassOffset"] as! Int] = 36
let guardedCache = GestaltPlist(dict: ["CacheData": guardedData, "CacheUUID": guardedLayout["CacheUUID"]!, "CacheExtra": [:]])
rejectedLayout(guardedCache, build: guardedBuild, original: guardedCache)
print("Passed: Ultra class 29/38 transitions and exact bytes, all build-specific choices, no-baseline/unknown-hardware/override/unexpected-state rejection, Watch7,18 native-class validation.")
