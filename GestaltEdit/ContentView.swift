import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject private var viewModel: GestaltViewModel

    var body: some View {
        Group {
            if GestaltAccess.isRunningSupportedOS() {
                TabView {
                    TweakWorkbench()
                        .tabItem { Label("Tools", systemImage: "switch.2") }

                    NavigationStack { AdvancedGestaltEditor() }
                        .tabItem { Label("Fields", systemImage: "list.bullet.rectangle") }

                    BackupLibrary()
                        .tabItem { Label("Restore", systemImage: "archivebox") }
                }
                .task { viewModel.load() }
            } else {
                UnsupportedOSView()
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

private struct UnsupportedOSView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text("Unsupported OS Version")
                .font(.title2.weight(.semibold))
            Text("GestaltEdit currently supports only iOS and visionOS 27 beta 1 through beta 4.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding(24)
    }
}

private struct TweakWorkbench: View {
    @EnvironmentObject private var viewModel: GestaltViewModel

    var body: some View {
        NavigationStack {
            List {
                Section { deviceStatus }

                if viewModel.plist != nil {
                    tweakSection(.region)
                    dynamicIslandSection
                    modelNameSection

                    ForEach(GestaltTweakCategory.allCases.filter { $0 != .region }) { category in
                        tweakSection(category)
                    }

                }

                Section(String(localized: "Developer")) {
                    DeveloperFooter()
                        .listRowInsets(EdgeInsets(top: 18, leading: 16, bottom: 18, trailing: 16))

                    NavigationLink {
                        RewardCodeView()
                    } label: {
                        Label {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("打赏开发者")
                                Text("扫描赞赏码支持 SUSS")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "heart.fill")
                                .foregroundStyle(.pink)
                        }
                    }
                }
            }
            .navigationTitle("MobileGestalt")
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
        let definitions = GestaltTweakCatalog.definitions.filter { $0.category == category }
        return Section(category.label) {
            ForEach(definitions) { definition in
                TweakToggle(
                    definition: definition,
                    isOn: Binding(
                        get: { viewModel.selectedTweaks.contains(definition.id) },
                        set: { viewModel.setTweak(definition.id, enabled: $0) }
                    )
                )
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
                            Text("Enable Siri AI (US Region)")
                            if viewModel.requiresForcedAIEnable {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                                    .accessibilityLabel("High Risk")
                            }
                        }
                        if viewModel.requiresForcedAIEnable {
                            Text("Unsupported device: force enable with device identity spoofing. Face ID or system stability may be affected.")
                                .font(.caption)
                                .foregroundStyle(.orange)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
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
        Section {
            Picker("Device Subtype", selection: $viewModel.dynamicIslandSubtype) {
                Text("No Change").tag(Int?.none)
                ForEach(DynamicIslandOption.all) { option in
                    Text("\(option.subtype) · \(option.title)").tag(Int?.some(option.subtype))
                }
            }
        } header: {
            Text("Dynamic Island")
        } footer: {
            Text("Selecting a subtype writes ArtworkDeviceSubType and the Dynamic Island support flag.")
        }
    }

    private var modelNameSection: some View {
        Section("Device Name") {
            Toggle("Change model name in About", isOn: $viewModel.changesModelName)
            if viewModel.changesModelName {
                TextField("Model Name", text: $viewModel.modelName)
                    .textInputAutocapitalization(.words)
            }
        }
    }

    private var applyBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(String(format: String(localized: "%d pending changes"), viewModel.stagedChangeCount))
                    .font(.subheadline.weight(.semibold))
                Text("Automatic backup before writing")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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

private struct DeveloperFooter: View {
    private let douyinURL = URL(string: "https://v.douyin.com/hHHMAlF5bE0/")!

    var body: some View {
        Link(destination: douyinURL) {
            HStack(spacing: 10) {
                avatarImage
                    .resizable()
                    .scaledToFill()
                    .frame(width: 34, height: 34)
                    .clipShape(Circle())

                Text("SUSS")
                    .font(.subheadline.weight(.medium))

                Spacer()
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("开发者 SUSS，点击打开抖音")
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

    var body: some View {
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
                Text(definition.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct BackupLibrary: View {
    @EnvironmentObject private var viewModel: GestaltViewModel
    @State private var backupToRestore: GestaltBackup?
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
                } footer: {
                    Text("Importing only adds a file to the backup library. It does not write immediately. The original plist is also backed up before every write.")
                }

                Section("Local Backups") {
                    if viewModel.backups.isEmpty {
                        Label("No Backups", systemImage: "archivebox")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(viewModel.backups) { backup in
                            BackupRow(backup: backup) {
                                backupToRestore = backup
                            }
                        }
                        .onDelete { offsets in
                            for index in offsets { viewModel.delete(viewModel.backups[index]) }
                        }
                    }
                }
            }
            .navigationTitle("Restore")
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
            .confirmationDialog(
                "Restore This MobileGestalt Backup?",
                isPresented: Binding(
                    get: { backupToRestore != nil },
                    set: { if !$0 { backupToRestore = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Restore and Write", role: .destructive) {
                    if let backupToRestore { viewModel.restore(backupToRestore) }
                    backupToRestore = nil
                }
                Button("Cancel", role: .cancel) { backupToRestore = nil }
            } message: {
                Text("The current file will be backed up first. SpringBoard will refresh automatically after restoring.")
            }
        }
    }
}

private struct BackupRow: View {
    let backup: GestaltBackup
    let restore: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(backup.createdAt, format: .dateTime.year().month().day().hour().minute().second())
                Text(ByteCountFormatter.string(fromByteCount: backup.byteCount, countStyle: .file))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            ShareLink(item: backup.url) {
                Image(systemName: "square.and.arrow.up")
            }
            .accessibilityLabel("Export Backup")
            Button("Restore", action: restore)
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .controlSize(.small)
            .accessibilityLabel("Restore Backup")
        }
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
