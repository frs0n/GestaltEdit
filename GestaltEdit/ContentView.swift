import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject private var viewModel: GestaltViewModel

    var body: some View {
        Group {
            if !GestaltAccess.supportsDeviceAccess {
                ContentUnavailableView(
                    "iOS 26 Is Not Supported",
                    systemImage: "iphone.slash",
                    description: Text("On-device MobileGestalt editing requires iOS / iPadOS 27 or later. iOS / iPadOS 26 is not supported.")
                )
            } else {
                TabView {
                    TweakWorkbench()
                        .tabItem { Label("Tools", systemImage: "switch.2") }

                    NavigationStack { AdvancedGestaltEditor().id(viewModel.deviceContextID) }
                        .tabItem { Label("Fields", systemImage: "list.bullet.rectangle") }

                    BackupLibrary().id(viewModel.deviceContextID)
                        .tabItem { Label("Restore", systemImage: "archivebox") }
                }
                .disabled(viewModel.isBusy)
                .task { viewModel.load() }
            }
        }
        .overlay {
            if viewModel.isRespringing {
                NeoSpringView()
            }
        }
        .alert(item: $viewModel.notice) { notice in
            Alert(
                title: Text(notice.title),
                message: Text(notice.message),
                dismissButton: .default(Text("OK"))
            )
        }
    }
}

private struct TweakWorkbench: View {
    @EnvironmentObject private var viewModel: GestaltViewModel

    var body: some View {
        NavigationStack {
            List {
                Section {
                    DeviceSelector(watch: viewModel.watch)
                    if viewModel.plist == nil { deviceStatus }
                }

                if viewModel.selectedDevice == .appleWatch {
                    WatchToolsSections()
                        .disabled(viewModel.plist == nil)
                } else if viewModel.plist != nil {
                    tweakSection(.region)
                    dynamicIslandSection
                    tweakSection(.display)
                    tweakSection(.ipad)
                    tweakSection(.hardware)
                    tweakSection(.audio)
                    Section {
                        DisclosureGroup("Settings Shortcuts") {
                            tweakRows(.settings)
                        }
                        DisclosureGroup("Internal & Research") {
                            tweakRows(.internalFeatures)
                        }
                        DisclosureGroup("Device Name") {
                            modelNameControls
                        }
                    } header: {
                        Text("Advanced")
                    }
                }

                Section(String(localized: "Developer")) {
                    DeveloperFooter()

                    PlacardPromotionLink()

                    NavigationLink {
                        RewardCodeView()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "heart.fill")
                                .foregroundStyle(.pink)
                                .frame(width: 40, height: 40)

                            VStack(alignment: .leading, spacing: 3) {
                                Text("打赏开发者")
                                Text("扫描赞赏码支持 SUSS")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()
                        }
                        .frame(minHeight: 40)
                    }
                }
            }
            .navigationTitle("GestaltEdit")
            .navigationBarTitleDisplayMode(.large)
            .refreshable { viewModel.load() }
            .safeAreaInset(edge: .bottom) {
                if viewModel.hasStagedTweaks {
                    applyBar
                }
            }
        }
    }

    private func tweakSection(_ category: GestaltTweakCategory) -> some View {
        Section(category.label) {
            if category == .ipad {
                tweakRow(.iPadOS)
                DisclosureGroup("Individual iPad Options") {
                    tweakRow(.stageManager)
                    tweakRow(.iPadApps)
                }
            } else {
                tweakRows(category)
            }
            if category == .display {
                Picker("Liquid Glass", selection: Binding<Int>(
                    get: {
                        if viewModel.selectedTweaks.contains(.enableLiquidGlassLowPerformance) { return 1 }
                        if viewModel.selectedTweaks.contains(.disableLiquidGlassLowPerformance) { return 0 }
                        return -1
                    },
                    set: { value in
                        viewModel.setTweak(.enableLiquidGlassLowPerformance, enabled: false)
                        viewModel.setTweak(.disableLiquidGlassLowPerformance, enabled: false)
                        if value >= 0 {
                            viewModel.setTweak(value == 1 ? .enableLiquidGlassLowPerformance : .disableLiquidGlassLowPerformance, enabled: true)
                        }
                    }
                )) {
                    Text("No Change").tag(-1)
                    Text("Reduced Effects").tag(1)
                    Text("Full Effects").tag(0)
                }
                DisclosureGroup("AOD Options") {
                    tweakRow(.alwaysOnDisplayVibrancy)
                    tweakRow(.aodHighLuminance)
                    tweakRow(.aodFlipbook)
                }
            }
            if category == .region {
                Toggle(
                    isOn: Binding(
                        get: { viewModel.stagesAIRegion },
                        set: { viewModel.setAIRegion(enabled: $0) }
                    )
                ) {
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text("Enable Siri AI")
                            if viewModel.requiresForcedAIEnable {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                                    .accessibilityLabel("High Risk")
                            }
                        }
                    }
                }
                Picker("Device Region", selection: Binding<String?>(
                    get: { viewModel.stagedAIRegionPresetID },
                    set: { viewModel.setRegionPreset($0) }
                )) {
                    Text("No Change").tag(String?.none)
                    ForEach(GestaltRegionPreset.all) { region in
                        Text(region.title).tag(String?.some(region.id))
                    }
                }
                .disabled(viewModel.stagesAIRegion)
            }
        }
    }

    private func tweakRows(_ category: GestaltTweakCategory) -> some View {
        let customControls: Set<GestaltTweakID> = [
            .supportsDynamicIsland, .alwaysOnDisplayVibrancy, .aodHighLuminance, .aodFlipbook,
            .enableLiquidGlassLowPerformance, .disableLiquidGlassLowPerformance
        ]
        let definitions = GestaltTweakCatalog.definitions.filter {
            $0.category == category && !customControls.contains($0.id) && $0.isAvailable()
        }
        return ForEach(definitions) { definition in
            tweakRow(definition.id)
        }
    }

    @ViewBuilder
    private func tweakRow(_ id: GestaltTweakID) -> some View {
        if let definition = GestaltTweakCatalog.definition(for: id), definition.isAvailable() {
            let included = (viewModel.selectedTweaks.contains(.iPadOS)
                && GestaltTweakCatalog.iPadIncludedTweaks.contains(id))
            TweakToggle(
                definition: definition,
                isOn: Binding(
                    get: { included || viewModel.selectedTweaks.contains(id) },
                    set: { viewModel.setTweak(id, enabled: $0) }
                ),
                included: included
            )
        }
    }

    @ViewBuilder
    private var deviceStatus: some View {
        if viewModel.plist == nil {
            HStack(spacing: 10) {
                if viewModel.isBusy || !viewModel.hasAttemptedLoad {
                    ProgressView()
                        .controlSize(.small)
                    Text("Reading MobileGestalt…")
                } else {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Unable to read MobileGestalt")
                        Button("Reload", action: viewModel.load)
                            .font(.footnote)
                    }
                }
            }
        } else {
            LabeledContent {
                Text("Connected")
                    .foregroundStyle(.green)
            } label: {
                Label(viewModel.aiRegionProfile?.marketingName ?? String(localized: "Current Device"), systemImage: "iphone")
            }
        }
    }

    private var dynamicIslandSection: some View {
        Section("Dynamic Island") {
            tweakRow(.supportsDynamicIsland)
            if viewModel.selectedTweaks.contains(.supportsDynamicIsland) || viewModel.dynamicIslandSubtype != nil {
                Picker("Island Layout", selection: $viewModel.dynamicIslandSubtype) {
                    Text("Keep Current Layout").tag(Int?.none)
                    ForEach(DynamicIslandOption.all) { option in
                        Text(option.title).tag(Int?.some(option.subtype))
                    }
                }
            }
        }
        .onChange(of: viewModel.selectedTweaks.contains(.supportsDynamicIsland)) { _, enabled in
            if !enabled { viewModel.dynamicIslandSubtype = nil }
        }
    }

    @ViewBuilder
    private var modelNameControls: some View {
        Toggle("Change model name in About", isOn: $viewModel.changesModelName)
        if viewModel.changesModelName {
            TextField("Model Name", text: $viewModel.modelName)
                .textInputAutocapitalization(.words)
        }
    }

    private var applyBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(String(format: String(localized: "%d pending changes"), viewModel.stagedChangeCount))
                    .font(.subheadline.weight(.semibold))
            }
            Spacer()
            Button("Apply") { viewModel.applySelectedTweaks() }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isBusy)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
    }
}

private struct PlacardPromotionLink: View {
    private let placardURL = URL(string: "https://github.com/frs0n/placard")!

    var body: some View {
        Link(destination: placardURL) {
            HStack(spacing: 12) {
                placardIcon
                    .resizable()
                    .scaledToFill()
                    .frame(width: 40, height: 40)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Placard")
                        .font(.body.weight(.medium))
                    Text("iPhone 动态壁纸")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .frame(minHeight: 40)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Placard，iPhone 动态壁纸，点击打开 GitHub")
    }

    private var placardIcon: Image {
        guard let url = Bundle.main.url(forResource: "PlacardIcon", withExtension: "png"),
              let image = UIImage(contentsOfFile: url.path) else {
            return Image(systemName: "rectangle.portrait.on.rectangle.portrait.angled")
        }
        return Image(uiImage: image)
    }
}

private struct DeveloperFooter: View {
    private let douyinURL = URL(string: "https://v.douyin.com/hHHMAlF5bE0/")!
    private let xURL = URL(string: "https://x.com/Frs0n_")!
    private let githubURL = URL(string: "https://github.com/frs0n")!

    var body: some View {
        HStack(spacing: 12) {
            avatarImage
                .resizable()
                .scaledToFill()
                .frame(width: 40, height: 40)
                .clipShape(Circle())
                .accessibilityHidden(true)

            Text("SUSS")
                .font(.subheadline.weight(.medium))

            Spacer(minLength: 0)

            HStack(spacing: 0) {
                socialLink("Douyin", label: "抖音", destination: douyinURL)
                socialLink("X", label: "X", destination: xURL)
                socialLink("GitHub", label: "GitHub", destination: githubURL)
            }
        }
        .frame(minHeight: 44)
    }

    private func socialLink(_ image: String, label: String, destination: URL) -> some View {
        Link(destination: destination) {
            Image(image)
                .resizable()
                .scaledToFit()
                .frame(width: 20, height: 20)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
        .accessibilityLabel("SUSS · \(label)")
    }

    private var avatarImage: Image {
        guard let url = Bundle.main.url(forResource: "SUSSAvatar", withExtension: "jpg"),
              let image = UIImage(contentsOfFile: url.path) else {
            return Image(systemName: "person.crop.circle")
        }
        return Image(uiImage: image)
    }
}

private struct RewardCodeView: View {
    private let rewardCodeImage: UIImage = {
        let imageURL = Bundle.main.url(forResource: "RewardCode", withExtension: "jpg")!
        return UIImage(contentsOfFile: imageURL.path)!
    }()

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                Image(uiImage: rewardCodeImage)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .shadow(color: .black.opacity(0.12), radius: 18, y: 8)
                    .accessibilityLabel("SUSS Reward Code")

                Text("感谢你对 SUSS 的支持")
                    .font(.headline)
                    .multilineTextAlignment(.center)

                Text("打开微信扫描上方赞赏码")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: 560)
            .padding(20)
            .frame(maxWidth: .infinity)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("打赏 SUSS")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct TweakToggle: View {
    let definition: GestaltTweakDefinition
    @Binding var isOn: Bool

    var included = false
    @State private var showsDetails = false

    var body: some View {
        HStack(spacing: 10) {
            Toggle(isOn: $isOn) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(definition.title)
                        if definition.isRisky {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundStyle(.orange)
                                .accessibilityLabel("High Risk")
                        }
                    }
                }
            }
            .disabled(included)
            if definition.isRisky || definition.showsDetails || [.supportsDynamicIsland, .chargeLimit, .alwaysOnDisplayVibrancy].contains(definition.id) {
                Button {
                    showsDetails = true
                } label: {
                    Image(systemName: "info.circle")
                        .frame(minWidth: 32, minHeight: 44)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(Text("About \(definition.title)"))
            }
        }
        .onChange(of: isOn) { _, enabled in
            if enabled && definition.isRisky && !included { showsDetails = true }
        }
        .alert(definition.title, isPresented: $showsDetails) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(definition.detail)
        }
    }
}

private struct BackupLibrary: View {
    @EnvironmentObject private var viewModel: GestaltViewModel
    @State private var showsBackupImporter = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        viewModel.createBackup()
                    } label: {
                        Label("Back Up Current MobileGestalt", systemImage: "plus.circle.fill")
                    }
                    .disabled(viewModel.plist == nil || viewModel.isBusy)

                    Button {
                        showsBackupImporter = true
                    } label: {
                        Label("Import Backup", systemImage: "square.and.arrow.down")
                    }
                    .disabled(viewModel.isBusy)
                }

                if !identityBackups.isEmpty {
                    Section {
                        backupRows(identityBackups)
                    } header: {
                        Text("Siri AI")
                    } footer: {
                        Text("After the Siri AI model download finishes, use this backup to remove device spoofing. Face ID and dictation will work again after restarting, while Siri AI settings stay enabled.")
                    }
                }

                Section("Local Backups") {
                    if ordinaryBackups.isEmpty {
                        Label("No Backups", systemImage: "archivebox")
                            .foregroundStyle(.secondary)
                    } else {
                        backupRows(ordinaryBackups)
                    }
                }
            }
            .navigationTitle(viewModel.selectedDevice == .appleWatch ? String(localized: "Apple Watch Backups") : String(localized: "Restore"))
            .refreshable { viewModel.refreshBackups() }
            .onAppear { viewModel.refreshBackups() }
            .fileImporter(
                isPresented: $showsBackupImporter,
                allowedContentTypes: [.propertyList],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    if let url = urls.first { viewModel.importBackup(from: url) }
                case .failure(let error):
                    viewModel.notice = GestaltNotice(kind: .error, message: error.localizedDescription)
                }
            }

        }
    }
    private var identityBackups: [GestaltBackup] {
        viewModel.backups.filter { $0.purpose == .siriAIIdentityRestore }
    }

    private var ordinaryBackups: [GestaltBackup] {
        viewModel.backups.filter { $0.purpose == .standard }
    }

    private func backupRows(_ backups: [GestaltBackup]) -> some View {
        ForEach(backups) { backup in
            BackupRow(backup: backup)
        }
        .onDelete { offsets in
            for index in offsets { viewModel.delete(backups[index]) }
        }
    }

}

private struct BackupRow: View {
    let backup: GestaltBackup

    var body: some View {
        NavigationLink {
            BackupDetail(backup: backup)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(backup.reason)
                Text(backup.createdAt, format: .dateTime.year().month().day().hour().minute().second())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct BackupDetail: View {
    @EnvironmentObject private var viewModel: GestaltViewModel
    @State private var showsRestoreConfirmation = false
    @State private var showsChanges = false
    let backup: GestaltBackup

    var body: some View {
        List {
            Section {
                Text(backup.reason)
                Text(backup.createdAt, format: .dateTime.year().month().day().hour().minute().second())
                    .foregroundStyle(.secondary)
                Text(ByteCountFormatter.string(fromByteCount: backup.byteCount, countStyle: .file))
                    .foregroundStyle(.secondary)
            }
            if let record = backup.record,
               record.source == .modification || record.source == .restore || record.source == .identityRecovery {
                Section {
                    DisclosureGroup(isExpanded: $showsChanges) {
                        if record.changes.isEmpty {
                            Text("No Field Changes").foregroundStyle(.secondary)
                        }
                        ForEach(record.changes) { change in
                            VStack(alignment: .leading, spacing: 8) {
                                if let title = fieldTitle(for: change) {
                                    Text(title)
                                    Text(change.path.joined(separator: " › "))
                                        .font(.caption.monospaced())
                                        .foregroundStyle(.secondary)
                                } else {
                                    Text(change.path.joined(separator: " › "))
                                        .font(.subheadline.monospaced())
                                }
                                Text(change.before ?? String(localized: "Not Present"))
                                    .foregroundStyle(.secondary)
                                Image(systemName: "arrow.down").foregroundStyle(.tertiary)
                                    .accessibilityLabel("Changes to")
                                Text(change.after ?? String(localized: "Not Present"))
                            }
                            .textSelection(.enabled)
                            .padding(.vertical, 4)
                        }
                    } label: {
                        Text(record.verified ? String(localized: "Changes") : String(localized: "Requested Changes"))
                    }
                }
            }
            Section {
                ShareLink(item: backup.url) { Label("Export Backup", systemImage: "square.and.arrow.up") }
                Button("Restore Backup") { showsRestoreConfirmation = true }
                    .disabled(viewModel.isBusy)
                    .confirmationDialog(
                        backup.purpose == .siriAIIdentityRestore
                            ? String(localized: "Remove Device Spoof?")
                            : String(localized: "Restore This MobileGestalt Backup?"),
                        isPresented: $showsRestoreConfirmation,
                        titleVisibility: .visible
                    ) {
                        Button(backup.purpose == .siriAIIdentityRestore
                               ? String(localized: "Remove Device Spoof")
                               : String(localized: "Restore and Write"), role: .destructive) {
                            viewModel.restore(backup)
                        }
                        Button("Cancel", role: .cancel) {}
                    } message: {
                        if backup.purpose == .siriAIIdentityRestore {
                            Text("Complete the Siri AI model download first. Your original device identity will be restored, and Face ID and dictation will work again after restarting. SiriMode and other AI settings stay enabled. The current file will be backed up before writing.")
                        } else {
                            Text(viewModel.selectedDevice == .appleWatch
                                 ? String(localized: "The current Apple Watch file will be backed up first. The watch interface will restart automatically after restoring.")
                                 : String(localized: "The current file will be backed up first. SpringBoard will refresh automatically after restoring."))
                        }
                    }
            }
        }
        .navigationTitle("Backup Details")
        .navigationBarTitleDisplayMode(.inline)

    }

    private func fieldTitle(for change: GestaltBackupChange) -> String? {
        guard change.path.count == 2, change.path.first == "CacheExtra", let key = change.path.dropFirst().first else {
            return nil
        }
        let matches = GestaltTweakCatalog.definitions.filter { $0.values[key] != nil }
        if matches.count == 1 { return matches[0].title }
        return WatchTweakCatalog.definitions.first { $0.keys.contains(key) }?.title
    }
}

private struct AdvancedGestaltEditor: View {
    @EnvironmentObject private var viewModel: GestaltViewModel

    @State private var searchText = ""
    @State private var activeEditor: FieldEditorRoute?

    private var cacheExtraKeys: [String] {
        filtered(viewModel.plist?.cacheExtraKeys ?? [], section: .cacheExtra)
    }

    private var topLevelKeys: [String] {
        filtered(
            viewModel.plist?.topLevelKeys.filter { $0 != "CacheExtra" } ?? [],
            section: .topLevel
        )
    }

    var body: some View {
        List {
            if viewModel.plist != nil {
                KeySection(
                    title: "CacheExtra",
                    keys: cacheExtraKeys,
                    value: { value(for: PlistKey(section: .cacheExtra, key: $0)) },
                    select: {
                        activeEditor = .edit(
                            PlistKey(section: .cacheExtra, key: $0)
                        )
                    }
                )

                KeySection(
                    title: String(localized: "Top Level"),
                    keys: topLevelKeys,
                    value: { value(for: PlistKey(section: .topLevel, key: $0)) },
                    select: {
                        activeEditor = .edit(
                            PlistKey(section: .topLevel, key: $0)
                        )
                    }
                )
            }
        }
        .navigationTitle("Advanced Field Editor")
        .searchable(text: $searchText, prompt: "Search key or value")
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button {
                    activeEditor = .addCacheExtra
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Add CacheExtra Field")
                .disabled(viewModel.plist == nil || viewModel.isBusy)

                Button("Save", action: viewModel.applyChanges)
                    .fontWeight(.semibold)
                    .disabled(!viewModel.isDirty || viewModel.isBusy)
            }
        }
        .sheet(item: $activeEditor) { editor in
            Group {
                switch editor {
                case .edit(let key):
                    ValueEditor(
                        key: key.key,
                        initialValue: value(for: key),
                        save: { update($0, for: key) },
                        delete: key.section == .cacheExtra
                            ? { deleteCacheExtraField(key.key) }
                            : nil
                    )
                case .addCacheExtra:
                    AddCacheExtraFieldEditor(save: addCacheExtraField)
                }
            }
            .presentationDetents([.medium, .large])
        }
    }

    private func filtered(_ keys: [String], section: PlistSection) -> [String] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return keys }

        return keys.filter { key in
            let reference = PlistKey(section: section, key: key)
            let info = PlistValueInfo.info(for: value(for: reference))
            return key.localizedCaseInsensitiveContains(query)
                || info.searchText.localizedCaseInsensitiveContains(query)
        }
    }

    private func value(for key: PlistKey) -> Any? {
        switch key.section {
        case .cacheExtra:
            viewModel.plist?.cacheExtra[key.key]
        case .topLevel:
            viewModel.plist?.value(forKey: key.key)
        }
    }

    private func update(_ value: Any, for key: PlistKey) {
        guard var plist = viewModel.plist else { return }
        switch key.section {
        case .cacheExtra:
            plist.setCacheExtra(value, forKey: key.key)
        case .topLevel:
            plist.setValue(value, forKey: key.key)
        }
        viewModel.plist = plist
        viewModel.isDirty = true
    }

    private func addCacheExtraField(key: String, value: Any) throws {
        guard var plist = viewModel.plist else { return }
        let normalizedKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedKey.isEmpty else {
            throw AddFieldError.emptyKey
        }
        guard plist.cacheExtra[normalizedKey] == nil else {
            throw AddFieldError.duplicateKey(normalizedKey)
        }

        plist.setCacheExtra(value, forKey: normalizedKey)
        viewModel.plist = plist
        viewModel.isDirty = true
    }

    private func deleteCacheExtraField(_ key: String) {
        guard var plist = viewModel.plist else { return }
        plist.removeCacheExtraValue(forKey: key)
        viewModel.plist = plist
        viewModel.isDirty = true
    }
}

private enum PlistSection: String {
    case cacheExtra
    case topLevel
}

private struct PlistKey: Identifiable {
    let section: PlistSection
    let key: String
    var id: String { "\(section.rawValue)/\(key)" }
}

private enum FieldEditorRoute: Identifiable {
    case edit(PlistKey)
    case addCacheExtra

    var id: String {
        switch self {
        case .edit(let key): "edit/\(key.id)"
        case .addCacheExtra: "add/cacheExtra"
        }
    }
}

private enum AddFieldError: LocalizedError {
    case emptyKey
    case duplicateKey(String)

    var errorDescription: String? {
        switch self {
        case .emptyKey:
            String(localized: "Key cannot be empty.")
        case .duplicateKey(let key):
            String(format: String(localized: "CacheExtra already contains the field: %@"), key)
        }
    }
}

private struct KeySection: View {
    let title: String
    let keys: [String]
    let value: (String) -> Any?
    let select: (String) -> Void

    var body: some View {
        Section(title) {
            if keys.isEmpty {
                Text("No Results")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(keys, id: \.self) { key in
                    Button { select(key) } label: {
                        KeyRow(key: key, value: value(key))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct KeyRow: View {
    let key: String
    let value: Any?

    var body: some View {
        let info = PlistValueInfo.info(for: value)
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(key)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(info.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
    }
}

private struct ValueEditor: View {
    @Environment(\.dismiss) private var dismiss

    let key: String
    let initialValue: Any?
    let save: (Any) -> Void
    let delete: (() -> Void)?

    @State private var kind: PlistValueKind
    @State private var text: String
    @State private var errorMessage: String?
    @State private var showsDeleteConfirmation = false

    init(
        key: String,
        initialValue: Any?,
        save: @escaping (Any) -> Void,
        delete: (() -> Void)? = nil
    ) {
        self.key = key
        self.initialValue = initialValue
        self.save = save
        self.delete = delete
        let kind = PlistValueKind.kind(of: initialValue)
        _kind = State(initialValue: kind)
        _text = State(initialValue: PlistValueInfo.encode(initialValue, as: kind))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Type") {
                    Picker("Type", selection: $kind) {
                        ForEach(PlistValueKind.allCases) { kind in
                            Text(kind.label).tag(kind)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section("Value") {
                    TextEditor(text: $text)
                        .font(.system(.body, design: .monospaced))
                        .frame(minHeight: 140)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }

                if delete != nil {
                    Section {
                        Button("Delete Field", role: .destructive) {
                            showsDeleteConfirmation = true
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .navigationTitle(key)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done", action: commit)
                        .fontWeight(.semibold)
                }
            }
            .confirmationDialog(
                "Delete CacheExtra Field?",
                isPresented: $showsDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    delete?()
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("The field will be removed from the file after you return to the editor and tap Save.")
            }
        }
    }

    private func commit() {
        do {
            save(try PlistValueInfo.parse(text, as: kind))
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct AddCacheExtraFieldEditor: View {
    @Environment(\.dismiss) private var dismiss

    let save: (String, Any) throws -> Void

    @State private var key = ""
    @State private var kind: PlistValueKind = .string
    @State private var text = ""
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Field") {
                    LabeledContent("Location", value: "CacheExtra")
                    TextField("Key", text: $key)
                        .font(.system(.body, design: .monospaced))
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }

                Section("Type") {
                    Picker("Type", selection: $kind) {
                        ForEach(PlistValueKind.allCases) { kind in
                            Text(kind.label).tag(kind)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section("Value") {
                    TextEditor(text: $text)
                        .font(.system(.body, design: .monospaced))
                        .frame(minHeight: 120)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Add Field")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add", action: commit)
                        .fontWeight(.semibold)
                }
            }
        }
    }

    private func commit() {
        do {
            let value = try PlistValueInfo.parse(text, as: kind)
            try save(key, value)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(GestaltViewModel())
}
