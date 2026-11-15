import SwiftUI

struct WatchToolsSections: View {
    @EnvironmentObject private var viewModel: GestaltViewModel

    var body: some View {
        ForEach(WatchTweakGroup.allCases) { group in
            Section {
                ForEach(WatchTweakCatalog.definitions.filter { $0.group == group }) { definition in
                    Toggle(definition.title, isOn: Binding(
                        get: { viewModel.selectedWatchTweaks.contains(definition.id) },
                        set: { enabled in
                            if enabled { viewModel.selectedWatchTweaks.insert(definition.id) }
                            else { viewModel.selectedWatchTweaks.remove(definition.id) }
                        }
                    ))
                    .disabled(definition.isFace && !viewModel.supportsWatchFaces)
                }
            } header: {
                Text(group.title)
            } footer: {
                if group == .faces {
                    if !viewModel.supportsWatchFaces {
                        Text("Watch face changes are unavailable on this watchOS build.")
                    } else {
                        Text("Ultra faces can prevent the Hermès Faubourg Party face from working.")
                    }
                } else if group == .sensors {
                    Text("Capability flags do not add missing sensors or override Health permissions.")
                } else if group == .intelligence {
                    Text("Availability depends on watchOS, hardware and Apple services.")
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
        Section {
            Button(action: viewModel.restartWatchInterface) {
                Label("Restart Watch Interface", systemImage: "arrow.clockwise")
            }
            .disabled(viewModel.isBusy || viewModel.hasStagedTweaks || viewModel.isDirty || !viewModel.watch.isReachable)
        } footer: {
            Text("Select capabilities to enable, then Apply. Use Restore to undo changes. Restart the watch interface after applying.")
        }
    }
}
