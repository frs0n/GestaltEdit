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
                deviceRow("iPhone / iPad", icon: "iphone", status: nil,
                          selected: viewModel.selectedDevice == .iPhone)
            }
            .disabled(viewModel.isBusy)

            Button {
                if watch.isPaired && watch.isInstalled && watch.isReachable {
                    select(.appleWatch)
                } else {
                    showsInstallation = true
                }
            } label: {
                deviceRow(watch.name, icon: "applewatch", status: watchStatus,
                          selected: viewModel.selectedDevice == .appleWatch)
            }
            .disabled(viewModel.isBusy)
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
                isExpanded = false
            }
            Button("Cancel", role: .cancel) { pendingDevice = nil }
        }
        .onChange(of: isExpanded) { _, expanded in if expanded { watch.refresh() } }
        .onChange(of: scenePhase) { _, phase in if phase == .active { watch.refresh() } }
        .sheet(isPresented: $showsInstallation) {
            NavigationStack {
                List {
                    Section {
                        if !watch.isPaired {
                            Text("Open the Watch app on this iPhone and pair your Apple Watch first.")
                        } else if !watch.isInstalled {
                            Text("Open the Watch app on this iPhone, find GestaltEdit in Available Apps, and tap Install. Then open GestaltEdit Helper on your Apple Watch.")
                        } else {
                            Text("Open GestaltEdit Helper on your Apple Watch and keep it nearby, then reload.")
                        }
                        if watch.isPaired && watch.isInstalled {
                            Button("Connect") {
                                showsInstallation = false
                                if viewModel.selectedDevice == .appleWatch { viewModel.load() }
                                else { select(.appleWatch) }
                            }
                            .disabled(!watch.isReachable || viewModel.isBusy)
                        } else {
                            Button("Open Watch App") {
                                UIApplication.shared.open(URL(string: "itms-watchs://")!) { opened in
                                    if opened { showsInstallation = false }
                                }
                            }
                        }
                    }
                }
                .navigationTitle(watch.isPaired
                                 ? (watch.isInstalled ? String(localized: "Connect Apple Watch") : String(localized: "Install Watch Helper"))
                                 : String(localized: "Set Up Apple Watch"))
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { showsInstallation = false } } }
            }
        }
    }

    private func select(_ device: GestaltViewModel.Device) {
        guard device != viewModel.selectedDevice else { return }
        if viewModel.isDirty || viewModel.hasStagedTweaks { pendingDevice = device }
        else {
            viewModel.selectDevice(device)
            isExpanded = false
        }
    }

    private var watchStatus: String {
        if !watch.isPaired { return String(localized: "Not Paired") }
        if !watch.isInstalled { return String(localized: "Not Installed") }
        return watch.isReachable ? String(localized: "Connected") : String(localized: "Offline")
    }

    private func deviceRow(_ title: String, icon: String, status: String?, selected: Bool) -> some View {
        HStack {
            Label(title, systemImage: icon)
            Spacer()
            if let status {
                Text(status).font(.subheadline).foregroundStyle(.secondary)
            }
            Image(systemName: "checkmark")
                .foregroundStyle(.tint)
                .opacity(selected ? 1 : 0)
                .accessibilityHidden(true)
        }
        .foregroundStyle(.primary)
        .contentShape(Rectangle())
    }
}
