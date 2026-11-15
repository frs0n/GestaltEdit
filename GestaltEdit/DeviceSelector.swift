import SwiftUI
import UIKit

struct DeviceSelector: View {
    @EnvironmentObject private var viewModel: GestaltViewModel
    @ObservedObject var watch: WatchConnection
    @State private var isExpanded = false
    @State private var showsInstallation = false
    @State private var pendingDevice: GestaltViewModel.Device?
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            Button { select(.iPhone) } label: {
                deviceRow("iPhone / iPad", icon: "iphone", selected: viewModel.selectedDevice == .iPhone)
            }
            .disabled(viewModel.isBusy)

            if watch.isPaired {
                Button { select(.appleWatch) } label: {
                    deviceRow(watch.name, icon: "applewatch", selected: viewModel.selectedDevice == .appleWatch)
                }
                .disabled(viewModel.isBusy)

                LabeledContent("Watch Helper") {
                    Text(watch.isInstalled ? (watch.isReachable ? String(localized: "Connected") : String(localized: "Offline")) : String(localized: "Not Installed"))
                        .foregroundStyle(watch.isReachable ? Color.green : Color.secondary)
                }
                if !watch.version.isEmpty {
                    LabeledContent("watchOS", value: watch.version)
                }
                if !watch.isInstalled {
                    Button("Install Watch Helper") { showsInstallation = true }
                } else if !watch.isReachable {
                    Text("Open GestaltEdit Helper on your Apple Watch and keep it nearby, then reload.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            } else {
                Label("No Apple Watch Paired", systemImage: "applewatch.slash")
                    .foregroundStyle(.secondary)
            }
        } label: {
            HStack {
                Label(viewModel.selectedDevice == .appleWatch ? watch.name : viewModel.aiRegionProfile?.marketingName ?? String(localized: "Current Device"),
                      systemImage: viewModel.selectedDevice == .appleWatch ? "applewatch" : "iphone")
                Spacer()
                if viewModel.isBusy {
                    ProgressView().controlSize(.small)
                } else {
                    Text(viewModel.selectedDevice == .appleWatch && !watch.isReachable
                         ? String(localized: "Offline")
                         : viewModel.plist == nil ? String(localized: "Not Connected") : String(localized: "Connected"))
                        .font(.subheadline)
                        .foregroundStyle(viewModel.plist == nil || (viewModel.selectedDevice == .appleWatch && !watch.isReachable) ? Color.secondary : Color.green)
                }
            }
        }
        .confirmationDialog("Discard Pending Changes?", isPresented: Binding(
            get: { pendingDevice != nil }, set: { if !$0 { pendingDevice = nil } }
        ), titleVisibility: .visible) {
            Button("Discard and Switch", role: .destructive) {
                if let pendingDevice { viewModel.selectDevice(pendingDevice) }
                pendingDevice = nil
            }
            Button("Cancel", role: .cancel) { pendingDevice = nil }
        }
        .onChange(of: isExpanded) { _, expanded in if expanded { watch.refresh() } }
        .onChange(of: scenePhase) { _, phase in if phase == .active { watch.refresh() } }
        .sheet(isPresented: $showsInstallation) {
            NavigationStack {
                List {
                    Section {
                        Text("Open the Watch app on this iPhone, find GestaltEdit in Available Apps, and tap Install. Then open GestaltEdit Helper on your Apple Watch.")
                        Button("Open Watch App") {
                            UIApplication.shared.open(URL(string: "itms-watchs://")!) { opened in
                                if opened { showsInstallation = false }
                            }
                        }
                    }
                    Section {
                        Text("If GestaltEdit is missing, reinstall an IPA that includes the Watch Helper. Both apps and their App Groups must be signed. You can also install the helper directly with Xcode.")
                    }
                }
                .navigationTitle("Install Watch Helper")
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { showsInstallation = false } } }
            }
        }
    }

    private func select(_ device: GestaltViewModel.Device) {
        guard device != viewModel.selectedDevice else { return }
        if viewModel.isDirty || viewModel.hasStagedTweaks { pendingDevice = device }
        else { viewModel.selectDevice(device) }
    }

    private func deviceRow(_ title: String, icon: String, selected: Bool) -> some View {
        HStack {
            Label(title, systemImage: icon)
            Spacer()
            if selected { Image(systemName: "checkmark").foregroundStyle(.tint) }
        }
        .foregroundStyle(.primary)
        .contentShape(Rectangle())
    }
}
