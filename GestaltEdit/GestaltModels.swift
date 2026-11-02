import Foundation
import Darwin

struct AIRegionProfile: Equatable {
    let marketingName: String
    let regulatoryModel: String

    fileprivate init(marketingName: String, regulatoryModel: String) {
        self.marketingName = marketingName
        self.regulatoryModel = regulatoryModel
    }

    private static let regulatoryModels: [String: String] = [
        "iPhone 17e": "A3575",
        "iPhone 17 Pro Max": "A3257",
        "iPhone 17 Pro": "A3256",
        "iPhone 17": "A3258",
        "iPhone Air": "A3260",
        "iPhone 16e": "A3212",
        "iPhone 16 Pro Max": "A3084",
        "iPhone 16 Pro": "A3083",
        "iPhone 16 Plus": "A3082",
        "iPhone 16": "A3081",
        "iPhone 15 Pro Max": "A2849",
        "iPhone 15 Pro": "A2848",
        "İphone 11": "A2221"
    ]

    private static let productTypes: [String: AIRegionProfile] = [
        "iPhone16,1": .init(marketingName: "iPhone 15 Pro", regulatoryModel: "A2848"),
        "iPhone16,2": .init(marketingName: "iPhone 15 Pro Max", regulatoryModel: "A2849"),
        "iPhone17,1": .init(marketingName: "iPhone 16 Pro", regulatoryModel: "A3083"),
        "iPhone17,2": .init(marketingName: "iPhone 16 Pro Max", regulatoryModel: "A3084"),
        "iPhone17,3": .init(marketingName: "iPhone 16", regulatoryModel: "A3081"),
        "iPhone17,4": .init(marketingName: "iPhone 16 Plus", regulatoryModel: "A3082"),
        "iPhone17,5": .init(marketingName: "iPhone 16e", regulatoryModel: "A3212"),

        // Apple Intelligence iPads. Cellular variants map to their US
        // equivalent, including devices sold originally in mainland China.
        "iPad13,4": .init(marketingName: "iPad Pro 11-inch (M1)", regulatoryModel: "A2377"),
        "iPad13,5": .init(marketingName: "iPad Pro 11-inch (M1)", regulatoryModel: "A2459"),
        "iPad13,6": .init(marketingName: "iPad Pro 11-inch (M1)", regulatoryModel: "A2301"),
        "iPad13,7": .init(marketingName: "iPad Pro 11-inch (M1)", regulatoryModel: "A2301"),
        "iPad13,8": .init(marketingName: "iPad Pro 12.9-inch (M1)", regulatoryModel: "A2378"),
        "iPad13,9": .init(marketingName: "iPad Pro 12.9-inch (M1)", regulatoryModel: "A2461"),
        "iPad13,10": .init(marketingName: "iPad Pro 12.9-inch (M1)", regulatoryModel: "A2379"),
        "iPad13,11": .init(marketingName: "iPad Pro 12.9-inch (M1)", regulatoryModel: "A2379"),
        "iPad13,16": .init(marketingName: "iPad Air (M1)", regulatoryModel: "A2588"),
        "iPad13,17": .init(marketingName: "iPad Air (M1)", regulatoryModel: "A2589"),
        "iPad14,3": .init(marketingName: "iPad Pro 11-inch (M2)", regulatoryModel: "A2759"),
        "iPad14,4": .init(marketingName: "iPad Pro 11-inch (M2)", regulatoryModel: "A2435"),
        "iPad14,5": .init(marketingName: "iPad Pro 12.9-inch (M2)", regulatoryModel: "A2436"),
        "iPad14,6": .init(marketingName: "iPad Pro 12.9-inch (M2)", regulatoryModel: "A2764"),
        "iPad14,8": .init(marketingName: "iPad Air 11-inch (M2)", regulatoryModel: "A2902"),
        "iPad14,9": .init(marketingName: "iPad Air 11-inch (M2)", regulatoryModel: "A2903"),
        "iPad14,10": .init(marketingName: "iPad Air 13-inch (M2)", regulatoryModel: "A2898"),
        "iPad14,11": .init(marketingName: "iPad Air 13-inch (M2)", regulatoryModel: "A2899"),
        "iPad15,3": .init(marketingName: "iPad Air 11-inch (M3)", regulatoryModel: "A3266"),
        "iPad15,4": .init(marketingName: "iPad Air 11-inch (M3)", regulatoryModel: "A3267"),
        "iPad15,5": .init(marketingName: "iPad Air 13-inch (M3)", regulatoryModel: "A3268"),
        "iPad15,6": .init(marketingName: "iPad Air 13-inch (M3)", regulatoryModel: "A3269"),
        "iPad16,1": .init(marketingName: "iPad mini (A17 Pro)", regulatoryModel: "A2993"),
        "iPad16,2": .init(marketingName: "iPad mini (A17 Pro)", regulatoryModel: "A2995"),
        "iPad16,3": .init(marketingName: "iPad Pro 11-inch (M4)", regulatoryModel: "A2836"),
        "iPad16,4": .init(marketingName: "iPad Pro 11-inch (M4)", regulatoryModel: "A2837"),
        "iPad16,5": .init(marketingName: "iPad Pro 13-inch (M4)", regulatoryModel: "A2925"),
        "iPad16,6": .init(marketingName: "iPad Pro 13-inch (M4)", regulatoryModel: "A2926"),
        "iPad16,8": .init(marketingName: "iPad Air 11-inch (M4)", regulatoryModel: "A3459"),
        "iPad16,9": .init(marketingName: "iPad Air 11-inch (M4)", regulatoryModel: "A3460"),
        "iPad16,10": .init(marketingName: "iPad Air 13-inch (M4)", regulatoryModel: "A3461"),
        "iPad16,11": .init(marketingName: "iPad Air 13-inch (M4)", regulatoryModel: "A3462"),
        "iPad17,1": .init(marketingName: "iPad Pro 11-inch (M5)", regulatoryModel: "A3357"),
        "iPad17,2": .init(marketingName: "iPad Pro 11-inch (M5)", regulatoryModel: "A3358"),
        "iPad17,3": .init(marketingName: "iPad Pro 13-inch (M5)", regulatoryModel: "A3360"),
        "iPad17,4": .init(marketingName: "iPad Pro 13-inch (M5)", regulatoryModel: "A3361")
    ]

    init?(plist: GestaltPlist) {
        let cacheExtra = plist.cacheExtra
        let marketingKeys = [
            "Z/dqyWS6OZTRy10UcmUAhw",
            "bbtR9jQx50Fv5Af/affNtA"
        ]

        let storedName = marketingKeys
            .compactMap { cacheExtra[$0] as? String }
            .first { Self.regulatoryModels[$0] != nil }
        let productType = Self.detectedProductType(in: plist)
        if let profile = Self.profile(forProductType: productType) {
            self = profile
            return
        }

        guard let marketingName = storedName,
              let regulatoryModel = Self.regulatoryModels[marketingName] else {
            return nil
        }
        self.marketingName = marketingName
        self.regulatoryModel = regulatoryModel
    }

    private static func profile(forProductType productType: String) -> AIRegionProfile? {
        if let profile = productTypes[productType] {
            return profile
        }

        // MobileGestalt can append a board/configuration suffix (for example,
        // "iPad16,3-A"). The device family identifier before the suffix is the
        // stable value used by the model map.
        guard let separator = productType.firstIndex(of: "-") else { return nil }
        return productTypes[String(productType[..<separator])]
    }

    fileprivate static func detectedProductType(in plist: GestaltPlist) -> String {
        plist.cacheExtra["0+nc/Udy4WNG8S+Q7a/s1A"] as? String ?? machineIdentifier
    }

    private static var machineIdentifier: String {
        var size = 0
        guard sysctlbyname("hw.machine", nil, &size, nil, 0) == 0,
              size > 0 else { return "" }
        var value = [CChar](repeating: 0, count: size)
        guard sysctlbyname("hw.machine", &value, &size, nil, 0) == 0 else {
            return ""
        }
        return String(cString: value)
    }
}

struct AIRegionConfiguration: Equatable {
    let profile: AIRegionProfile
    let spoofedProductType: String?
    let spoofedHardwareModel: String?
    let spoofedCPUModel: String?

    var requiresDeviceSpoofing: Bool { spoofedProductType != nil }

    static func resolve(for plist: GestaltPlist) -> AIRegionConfiguration {
        if let profile = AIRegionProfile(plist: plist) {
            return AIRegionConfiguration(
                profile: profile,
                spoofedProductType: nil,
                spoofedHardwareModel: nil,
                spoofedCPUModel: nil
            )
        }

        let productType = AIRegionProfile.detectedProductType(in: plist)
        if productType.hasPrefix("iPad") {
            return AIRegionConfiguration(
                profile: AIRegionProfile(marketingName: "iPad mini (A17 Pro)", regulatoryModel: "A2993"),
                spoofedProductType: "iPad16,1",
                spoofedHardwareModel: "J410AP",
                spoofedCPUModel: "t8130"
            )
        }

        return AIRegionConfiguration(
            profile: AIRegionProfile(marketingName: "iPhone 15 Pro", regulatoryModel: "A2848"),
            spoofedProductType: "iPhone16,1",
            spoofedHardwareModel: "D83AP",
            spoofedCPUModel: "t8130"
        )
    }
}

struct GestaltNotice: Identifiable {
    enum Kind { case error, backupCreated, riskWarning }

    let id = UUID()
    let kind: Kind
    let message: String

    var title: String {
        switch kind {
        case .error: String(localized: "Operation Failed")
        case .backupCreated: String(localized: "Backup Complete")
        case .riskWarning: String(localized: "High Risk")
        }
    }
}

enum PlistValueKind: String, CaseIterable, Identifiable {
    case string
    case integer
    case float
    case boolean
    case data
    case array
    case dictionary

    var id: String { rawValue }

    var label: String {
        switch self {
        case .string: String(localized: "String")
        case .integer: String(localized: "Integer")
        case .float: String(localized: "Float")
        case .boolean: String(localized: "Boolean")
        case .data: String(localized: "Data")
        case .array: String(localized: "Array")
        case .dictionary: String(localized: "Dictionary")
        }
    }

    static func kind(of value: Any?) -> PlistValueKind {
        switch value {
        case is String:
            .string
        case let number as NSNumber:
            CFGetTypeID(number) == CFBooleanGetTypeID()
                ? .boolean
                : (CFNumberIsFloatType(number) ? .float : .integer)
        case is Data:
            .data
        case is NSArray:
            .array
        case is NSDictionary:
            .dictionary
        default:
            .string
        }
    }
}

struct PlistValueInfo {
    let kind: PlistValueKind
    let summary: String
    let searchText: String

    static func info(for value: Any?) -> PlistValueInfo {
        let kind = PlistValueKind.kind(of: value)
        let text = encode(value, as: kind)
        let summary: String

        switch kind {
        case .string:
            summary = text.isEmpty ? String(localized: "Empty string") : text
        case .integer, .float, .boolean:
            summary = text
        case .data:
            summary = String(format: String(localized: "Data (%d bytes)"), (value as? Data)?.count ?? 0)
        case .array:
            summary = String(format: String(localized: "Array (%d items)"), (value as? NSArray)?.count ?? 0)
        case .dictionary:
            summary = String(format: String(localized: "Dictionary (%d items)"), (value as? NSDictionary)?.count ?? 0)
        }

        return PlistValueInfo(kind: kind, summary: summary, searchText: text)
    }

    static func encode(_ value: Any?, as kind: PlistValueKind) -> String {
        switch kind {
        case .string:
            value as? String ?? ""
        case .integer, .float:
            (value as? NSNumber)?.stringValue ?? ""
        case .boolean:
            (value as? NSNumber)?.boolValue == true ? "true" : "false"
        case .data:
            (value as? Data)?.base64EncodedString() ?? ""
        case .array, .dictionary:
            jsonText(for: value)
        }
    }

    static func parse(_ text: String, as kind: PlistValueKind) throws -> Any {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        switch kind {
        case .string:
            return text
        case .integer:
            guard let value = Int64(trimmed) else {
                throw PlistValueError.invalid(String(localized: "Invalid integer"))
            }
            return NSNumber(value: value)
        case .float:
            guard let value = Double(trimmed) else {
                throw PlistValueError.invalid(String(localized: "Invalid floating-point number"))
            }
            return NSNumber(value: value)
        case .boolean:
            switch trimmed.lowercased() {
            case "true", "1", "yes":
                return NSNumber(value: true)
            case "false", "0", "no":
                return NSNumber(value: false)
            default:
                throw PlistValueError.invalid(String(localized: "Enter true or false"))
            }
        case .data:
            guard let data = Data(base64Encoded: trimmed) else {
                throw PlistValueError.invalid(String(localized: "Invalid Base64 data"))
            }
            return data
        case .array:
            return try jsonObject(from: trimmed, expected: NSArray.self)
        case .dictionary:
            return try jsonObject(from: trimmed, expected: NSDictionary.self)
        }
    }

    private static func jsonText(for value: Any?) -> String {
        guard let value,
              JSONSerialization.isValidJSONObject(value),
              let data = try? JSONSerialization.data(
                withJSONObject: value,
                options: [.prettyPrinted, .sortedKeys]
              ) else { return "" }
        return String(data: data, encoding: .utf8) ?? ""
    }

    private static func jsonObject<T>(from text: String, expected: T.Type) throws -> Any {
        guard let data = text.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data),
              object is T else {
            throw PlistValueError.invalid(
                String(format: String(localized: "Invalid JSON for type %@"), String(describing: T.self))
            )
        }
        return object
    }
}

enum PlistValueError: LocalizedError {
    case invalid(String)

    var errorDescription: String? {
        switch self {
        case .invalid(let message): message
        }
    }
}

struct GestaltPlist {
    var dict: [String: Any]

    var topLevelKeys: [String] {
        dict.keys.sorted()
    }

    var cacheExtra: [String: Any] {
        get { dict["CacheExtra"] as? [String: Any] ?? [:] }
        set { dict["CacheExtra"] = newValue }
    }

    var cacheExtraKeys: [String] {
        cacheExtra.keys.sorted()
    }

    func value(forKey key: String) -> Any? {
        dict[key]
    }

    mutating func setValue(_ value: Any, forKey key: String) {
        dict[key] = value
    }

    mutating func setCacheExtra(_ value: Any, forKey key: String) {
        var values = cacheExtra
        values[key] = value
        cacheExtra = values
    }

    mutating func removeCacheExtraValue(forKey key: String) {
        var values = cacheExtra
        values.removeValue(forKey: key)
        cacheExtra = values
    }
}
