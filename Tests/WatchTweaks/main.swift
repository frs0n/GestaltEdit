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
let changed = try WatchTweakCatalog.apply(["hermes", "ultra", "actionButton", "doubleTap", "keyboard", "onDeviceSiri"], to: original, build: build, directory: resources)
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
