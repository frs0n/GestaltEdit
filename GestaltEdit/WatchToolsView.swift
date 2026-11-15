import SwiftUI

struct WatchToolsSections: View {
    @EnvironmentObject private var viewModel: GestaltViewModel

    var body: some View {
        Section {
            Toggle("Enable Siri AI", isOn: Binding(
                get: { viewModel.selectedWatchTweaks.contains("intelligence") },
                set: { enabled in
                    if enabled { viewModel.selectedWatchTweaks.insert("intelligence") }
                    else { viewModel.selectedWatchTweaks.remove("intelligence") }
                }
            ))
        } header: {
            Text("Apple Intelligence")
        } footer: {
            Text("Automatically adjusts unsupported regions to the United States.")
        }
        ForEach(WatchTweakGroup.allCases.filter { $0 != .intelligence }) { group in
            Section {
                ForEach(WatchTweakCatalog.definitions.filter { $0.group == group }) { definition in
                    Toggle(definition.title, isOn: Binding(
                        get: { viewModel.selectedWatchTweaks.contains(definition.id) },
                        set: { enabled in
                            if enabled { viewModel.selectedWatchTweaks.insert(definition.id) }
                            else {
                                viewModel.selectedWatchTweaks.remove(definition.id)
                                if definition.id == "ultra" {
                                    viewModel.watchUltraFaceClass = viewModel.currentWatchUltraFaceClass
                                        ?? viewModel.watchUltraFaceClassOptions.first ?? 29
                                }
                            }
                        }
                    ))
                    .disabled(definition.isFace && !viewModel.supportsWatchFaces)
                }
                if group == .faces && viewModel.watchUltraFaceClassOptions.count > 1 &&
                    (viewModel.selectedWatchTweaks.contains("ultra") || viewModel.currentWatchUltraFaceClass != nil) {
                    Picker("Ultra Face Layout", selection: Binding(
                        get: { viewModel.watchUltraFaceClass },
                        set: { layout in
                            viewModel.watchUltraFaceClass = layout
                            viewModel.selectedWatchTweaks.insert("ultra")
                        }
                    )) {
                        ForEach(viewModel.watchUltraFaceClassOptions, id: \.self) { layout in
                            Text("Class \(layout)").tag(layout)
                        }
                    }
                }
            } header: {
                Text(group.title)
            } footer: {
                if group == .faces {
                    if !viewModel.supportsWatchFaces {
                        Text("Watch face changes are unavailable on this watchOS build.")
                    } else {
                        Text("Ultra faces can prevent the Hermès Faubourg Party face from working.")
                        if viewModel.watchUltraFaceClassOptions.count > 1 {
                            Text("A larger Ultra layout may affect other watch faces and complications.")
                        }
                    }
                } else if group == .sensors {
                    Text("Capability flags do not add missing sensors or override Health permissions.")
                }
            }
        }
        Section("Watch Region") {
            Picker("Region Code", selection: $viewModel.watchRegionCode) {
                Text("No Change").tag("")
                ForEach(WatchTweakCatalog.regions, id: \.1) { region in
                    Text(region.0).tag(region.1)
                }
            }
            Picker("Sales Region", selection: $viewModel.watchSalesRegion) {
                Text("No Change").tag("")
                ForEach(WatchTweakCatalog.regions, id: \.2) { region in
                    Text(region.0).tag(region.2)
                }
            }
        }
        Section("Watch Resolution") {
            Picker("Screen Resolution", selection: $viewModel.watchResolution) {
                Text("No Change").tag(-1)
                ForEach(WatchTweakCatalog.resolutions.indices, id: \.self) { index in
                    let resolution = WatchTweakCatalog.resolutions[index]
                    Text("\(resolution.0) · \(resolution.1) × \(resolution.2)").tag(index)
                }
            }
        }
    }
}
