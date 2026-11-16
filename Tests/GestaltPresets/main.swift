import Foundation

// xcrun swiftc GestaltEdit/GestaltModels.swift GestaltEdit/GestaltTweaks.swift GestaltEdit/GestaltBackupStore.swift Tests/GestaltPresets/main.swift -o /tmp/gestalt-preset-tests
let catalog = GestaltTweakCatalog.self
let iPad = catalog.definition(for: .iPadOS)!
let stage = catalog.definition(for: .stageManager)!
let apps = catalog.definition(for: .iPadApps)!
for component in [stage, apps] {
    for (key, value) in component.values {
        precondition(NSDictionary(dictionary: [key: value]).isEqual(to: [key: iPad.values[key]!]))
    }
}

var selection: Set<GestaltTweakID> = [.stageManager, .iPadApps, .bootChime]
selection = catalog.selecting(.iPadOS, enabled: true, in: selection)
precondition(selection == [.iPadOS, .bootChime])
selection = catalog.selecting(.stageManager, enabled: true, in: selection)
precondition(selection == [.iPadOS, .bootChime])
selection = catalog.selecting(.iPadOS, enabled: false, in: selection)
precondition(selection == [.bootChime])
selection = catalog.selecting(.stageManager, enabled: true, in: selection)
precondition(selection == [.bootChime, .stageManager])
selection = catalog.selecting(.enableLiquidGlassLowPerformance, enabled: true, in: selection)
selection = catalog.selecting(.disableLiquidGlassLowPerformance, enabled: true, in: selection)
precondition(!selection.contains(.enableLiquidGlassLowPerformance))
precondition(selection.contains(.disableLiquidGlassLowPerformance))

// A rejected binary patch must leave both CacheExtra and CacheData intact.
var invalid = GestaltPlist(dict: ["CacheExtra": ["existing": "keep"], "CacheData": Data([0, 1])])
let before = NSDictionary(dictionary: invalid.dict)
do {
    try invalid.apply(definition: iPad)
    fatalError("Expected invalid CacheData to fail")
} catch {
    precondition(before.isEqual(to: invalid.dict))
}

// Exercise the existing validated marker path with a synthetic cache, keeping
// all unrelated bytes and capability values intact.
var hex = Array(repeating: Character("0"), count: 2000)
for (index, value) in Array("abcd").enumerated() { hex[1700 + index] = value }
hex[1700 - 67] = "1"
hex[1700 + 13] = "1"
func bytes(_ hex: [Character]) -> Data {
    Data(stride(from: 0, to: hex.count, by: 2).map { UInt8(String(hex[$0...($0 + 1)]), radix: 16)! })
}
let originalData = bytes(hex)
var valid = GestaltPlist(dict: ["CacheExtra": ["existing": "keep"], "CacheData": originalData])
try valid.apply(definition: iPad)
hex[1700 - 67] = "3"
precondition(valid.dict["CacheData"] as? Data == bytes(hex))
precondition(valid.cacheExtra["existing"] as? String == "keep")
precondition(valid.cacheExtra["qeaj75wk3HF4DwQ8qbIi7g"] as? Int == 1)
precondition(valid.cacheExtra["9MZ5AdH43csAUajl/dU+IQ"] as? [Int] == [1, 2])
let applied = NSDictionary(dictionary: valid.dict)
try valid.apply(definition: iPad)
precondition(applied.isEqual(to: valid.dict))

var island = GestaltPlist(dict: ["CacheExtra": ["oPeik/9e8lQWMszEjbPzng": ["keep": 42]]])
try island.setDynamicIslandSubtype(2556)
precondition(island.cacheExtra["YlEtTtHlNesRBMal1CqRaA"] as? Int == 1)
precondition((island.cacheExtra["oPeik/9e8lQWMszEjbPzng"] as? [String: Any])?["keep"] as? Int == 42)
print("Passed: iPad bundle, selection dependencies, Glass exclusivity, atomic failure, validated CacheData patch, reapplication and Dynamic Island.")

let os26 = OperatingSystemVersion(majorVersion: 26, minorVersion: 0, patchVersion: 0)
let os264 = OperatingSystemVersion(majorVersion: 26, minorVersion: 4, patchVersion: 0)
let os27 = OperatingSystemVersion(majorVersion: 27, minorVersion: 0, patchVersion: 0)
let highAOD = catalog.definition(for: .aodHighLuminance)!
precondition(!highAOD.isAvailable(on: os26) && highAOD.isAvailable(on: os27))
var unsupported = GestaltPlist(dict: ["CacheExtra": ["keep": "original"], "CacheData": Data([1, 2, 3])])
let unsupportedOriginal = NSDictionary(dictionary: unsupported.dict)
do {
    try unsupported.apply(definition: highAOD, on: os26)
    fatalError("Expected unsupported system version to fail")
} catch {
    precondition(unsupportedOriginal.isEqual(to: unsupported.dict))
}

// Capability-only presets must not change device identity or binary CacheData.
var capabilities = GestaltPlist(dict: ["CacheExtra": ["h9jDsbgj7xIVeIQ8S3/X3Q": "iPhone15,4"], "CacheData": Data([1, 2, 3])])
for definition in catalog.definitions where definition.showsDetails {
    try capabilities.apply(definition: definition, on: os27)
}
precondition(capabilities.dict["CacheData"] as? Data == Data([1, 2, 3]))
precondition(capabilities.cacheExtra["h9jDsbgj7xIVeIQ8S3/X3Q"] as? String == "iPhone15,4")
precondition(capabilities.cacheExtra["a3n5T9sFtlyQ74NEp9ESxg"] == nil)
let serialized = try PropertyListSerialization.data(fromPropertyList: capabilities.dict, format: .binary, options: 0)
let roundTrip = try PropertyListSerialization.propertyList(from: serialized, format: nil) as! [String: Any]
precondition(NSDictionary(dictionary: capabilities.dict).isEqual(to: roundTrip))

for region in GestaltRegionPreset.all {
    var regional = GestaltPlist(dict: ["CacheExtra": ["h9jDsbgj7xIVeIQ8S3/X3Q": "iPhone15,4", "a3n5T9sFtlyQ74NEp9ESxg": 2]])
    regional.apply(region: region)
    precondition(regional.cacheExtra["h63QSdBCiT/z0WU6rdQv6Q"] as? String == region.code)
    precondition(regional.cacheExtra["yK+xavymRGZ3xWc1tb8XDg"] as? String == region.salesCode)
    precondition(regional.cacheExtra.count == 4)
}
precondition(Set(catalog.definitions.map(\.id)) == Set(GestaltTweakID.allCases))
precondition(catalog.definitions.count == Set(catalog.definitions.map(\.id)).count)
print("Passed: OS 26/27 boundaries, rejected-write atomicity, capability-only identity preservation, binary plist round-trip and independent region presets.")

// Supported non-US regions retain all region/model fields, including absent
// fields. Only known regional restrictions trigger a device-region override.
for code in ["LL", "J", "TA", "ZA", "B", "C", "FD", "D", "F", "IP", "unknown"] {
    var device = GestaltPlist(dict: ["CacheExtra": [
        "0+nc/Udy4WNG8S+Q7a/s1A": "iPhone15,4",
        "h63QSdBCiT/z0WU6rdQv6Q": code,
        "yK+xavymRGZ3xWc1tb8XDg": code + "/A",
        "zHeENZu+wbg7PUprwNwBWg": code + "/A",
        "97JDvERpVwO+GHtthIh7hA": "keep-original-model"
    ]])
    let originalRegion = AIRegionConfiguration.regionValues(in: device)
    let configuration = AIRegionConfiguration.resolve(for: device, osMajorVersion: 27)
    precondition(!configuration.changesRegion)
    configuration.apply(to: &device)
    precondition(originalRegion.isEqual(AIRegionConfiguration.regionValues(in: device)))
    precondition(device.cacheExtra["a3n5T9sFtlyQ74NEp9ESxg"] as? Int == 2)
    precondition(device.cacheExtra["h9jDsbgj7xIVeIQ8S3/X3Q"] as? String == "iPhone16,1")
}
do {
    var device = GestaltPlist(dict: ["CacheExtra": [
        "0+nc/Udy4WNG8S+Q7a/s1A": "iPhone16,1",
        "zHeENZu+wbg7PUprwNwBWg": "CH/A"
    ]])
    let configuration = AIRegionConfiguration.resolve(for: device, osMajorVersion: 27)
    precondition(configuration.changesRegion)
    configuration.apply(to: &device)
    precondition(device.cacheExtra["h63QSdBCiT/z0WU6rdQv6Q"] as? String == "LL")
    precondition(device.cacheExtra["yK+xavymRGZ3xWc1tb8XDg"] as? String == "LL/A")
    precondition(device.cacheExtra["zHeENZu+wbg7PUprwNwBWg"] as? String == "LL/A")
    precondition(device.cacheExtra["97JDvERpVwO+GHtthIh7hA"] as? String == "A2848")
}
for key in ["h63QSdBCiT/z0WU6rdQv6Q", "yK+xavymRGZ3xWc1tb8XDg", "zHeENZu+wbg7PUprwNwBWg"] {
    let device = GestaltPlist(dict: ["CacheExtra": [key: " ch/a "]])
    precondition(AIRegionConfiguration.resolve(for: device).changesRegion)
}
var missingRegion = GestaltPlist(dict: ["CacheExtra": [:]])
let missingConfig = AIRegionConfiguration.resolve(for: missingRegion, osMajorVersion: 27)
missingConfig.apply(to: &missingRegion)
precondition(AIRegionConfiguration.regionValues(in: missingRegion).count == 0)
print("Passed: Siri AI preserves supported/unknown regions and model values; only known restricted regions trigger adjustment.")

// Both absent and explicit original identity fields must survive a full
// setup -> download -> unspoof cycle. Recovery must preserve later edits.
for identity: [String: Any] in [[:], [
    "h9jDsbgj7xIVeIQ8S3/X3Q": "iPhone15,4",
    "oYicEKzVTz4/CxxE05pEgQ": "D37AP",
    "5pYKlGnYYBzGvAlIU8RjEQ": "t8120"
]] {
    var extra: [String: Any] = [
        "0+nc/Udy4WNG8S+Q7a/s1A": "iPhone15,4",
        "h63QSdBCiT/z0WU6rdQv6Q": "CH",
        "97JDvERpVwO+GHtthIh7hA": "original-model"
    ]
    extra.merge(identity) { _, new in new }
    let original = GestaltPlist(dict: ["CacheExtra": extra, "CacheData": Data([4, 5, 6])])
    let configuration = AIRegionConfiguration.resolve(for: original, osMajorVersion: 27)
    precondition(configuration.requiresDeviceSpoofing)
    var setup = original
    configuration.apply(to: &setup)
    precondition(setup.cacheExtra["A62OafQ85EJAiiqKn4agtg"] as? Int == 1)
    precondition(setup.cacheExtra["a3n5T9sFtlyQ74NEp9ESxg"] as? Int == 2)
    let specialSnapshot = SiriAIIdentityRestore.restoring(setup, from: original)
    var afterDownload = setup
    afterDownload.setCacheExtra("keep-later-edit", forKey: "unrelated")
    afterDownload.setCacheExtra("TA", forKey: "h63QSdBCiT/z0WU6rdQv6Q")
    let recovered = SiriAIIdentityRestore.restoring(afterDownload, from: specialSnapshot)
    precondition(SiriAIIdentityRestore.values(in: recovered).isEqual(SiriAIIdentityRestore.values(in: original)))
    precondition(recovered.cacheExtra["A62OafQ85EJAiiqKn4agtg"] as? Int == 1)
    precondition(recovered.cacheExtra["a3n5T9sFtlyQ74NEp9ESxg"] as? Int == 2)
    precondition(recovered.cacheExtra["h63QSdBCiT/z0WU6rdQv6Q"] as? String == "TA")
    precondition(recovered.cacheExtra["unrelated"] as? String == "keep-later-edit")
    precondition(recovered.dict["CacheData"] as? Data == original.dict["CacheData"] as? Data)
    precondition(SiriAIIdentityRestore.sameDevice(recovered, specialSnapshot))
    let anotherDevice = GestaltPlist(dict: ["CacheExtra": ["0+nc/Udy4WNG8S+Q7a/s1A": "iPhone14,6"]])
    precondition(!SiriAIIdentityRestore.sameDevice(anotherDevice, specialSnapshot))
}
let specialBackup = GestaltBackup(url: URL(fileURLWithPath: "/tmp/SiriAI_RestoreIdentity_AfterModelDownload_2026-11-16.plist"), createdAt: Date(), byteCount: 0)
precondition(specialBackup.purpose == .siriAIIdentityRestore)
precondition(specialBackup.displayTitle != nil)
let ordinaryBackup = GestaltBackup(url: URL(fileURLWithPath: "/tmp/MobileGestalt_2026-11-16.plist"), createdAt: Date(), byteCount: 0)
precondition(ordinaryBackup.purpose == .standard && ordinaryBackup.displayTitle == nil)
print("Passed: temporary spoof setup, identity-only recovery, SiriMode=2 retention, unrelated-edit preservation and backup purpose recognition.")
