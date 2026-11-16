import SwiftUI
import UIKit

struct DeviceSelector: View {
    @EnvironmentObject private var viewModel: GestaltViewModel
    @ObservedObject var watch: WatchConnection
    @State private var showsInstallation = false
    @State private var pendingDevice: GestaltViewModel.Device?
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            Button {
                withAnimation { viewModel.isDeviceSelectorExpanded.toggle() }
            } label: {
                HStack {
                    Label("Devices", systemImage: "externaldrive.connected.to.line.below")
                    Spacer()
                    Image(systemName: viewModel.isDeviceSelectorExpanded ? "chevron.down" : "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("device-selector-toggle")

            if viewModel.isDeviceSelectorExpanded {
                Button { select(.iPhone) } label: {
                    deviceRow(localDeviceName,
                              icon: UIDevice.current.userInterfaceIdiom == .pad ? "ipad" : "iphone",
                              status: viewModel.selectedDevice == .iPhone
                                  ? (viewModel.plist == nil ? String(localized: "Not Connected") : String(localized: "Connected"))
                                  : nil,
                              selected: viewModel.selectedDevice == .iPhone,
                              connected: viewModel.selectedDevice == .iPhone && viewModel.plist != nil)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("device-selector-iphone")
                .disabled(viewModel.isBusy)

                Button {
                    if watch.isPaired && watch.isInstalled && watch.isReachable {
                        select(.appleWatch)
                    } else {
                        showsInstallation = true
                    }
                } label: {
                    deviceRow(watch.name, icon: "applewatch", status: watchStatus,
                              selected: viewModel.selectedDevice == .appleWatch,
                              connected: watch.isPaired && watch.isInstalled && watch.isReachable)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("device-selector-watch")
                .disabled(viewModel.isBusy)
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
        .onAppear { watch.refresh() }
        .onChange(of: viewModel.isDeviceSelectorExpanded) { _, expanded in
            if expanded { watch.refresh() }
        }
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

    private var localDeviceName: String {
        AIRegionProfile.currentDeviceMarketingName ?? UIDevice.current.model
    }

    private func select(_ device: GestaltViewModel.Device) {
        guard device != viewModel.selectedDevice else { return }
        if viewModel.isDirty || viewModel.hasStagedTweaks { pendingDevice = device }
        else {
            viewModel.selectDevice(device)
        }
    }

    private var watchStatus: String {
        if !watch.isPaired { return String(localized: "Not Paired") }
        if !watch.isInstalled { return String(localized: "Not Installed") }
        return watch.isReachable ? String(localized: "Connected") : String(localized: "Offline")
    }

    private func deviceRow(_ title: String, icon: String, status: String?, selected: Bool, connected: Bool) -> some View {
        HStack {
            Label(title, systemImage: icon)
            Spacer()
            if selected && viewModel.isBusy {
                ProgressView().controlSize(.small)
            } else if let status {
                Text(status).font(.subheadline).foregroundStyle(connected ? Color.blue : Color.secondary)
            }
            Image(systemName: "checkmark")
                .foregroundStyle(Color.blue)
                .opacity(selected ? 1 : 0)
                .accessibilityHidden(true)
        }
        .foregroundStyle(.primary)
        .contentShape(Rectangle())
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
