#if targetEnvironment(macCatalyst)
import SwiftUI

private enum MacSidebarSelection: Hashable {
    case overview
    case device(UUID)
    case settings
}

struct MacControllerRootView: View {
    @ObservedObject var connection: ConnectionManager
    @State private var selection: MacSidebarSelection? = .overview
    @State private var showPairing = false

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Section("Control") {
                    Label("Overview", systemImage: "rectangle.grid.2x2")
                        .tag(MacSidebarSelection.overview)
                }
                Section("Apple TVs") {
                    ForEach(connection.remoteDevices) { device in
                        MacDeviceSidebarRow(device: device)
                            .tag(MacSidebarSelection.device(device.id))
                    }
                    if connection.remoteDevices.isEmpty {
                        Text("No paired devices").foregroundStyle(.secondary)
                    }
                }
                Section {
                    Label("Settings", systemImage: "gearshape")
                        .tag(MacSidebarSelection.settings)
                }
            }
            .navigationTitle("Device Control")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showPairing = true } label: { Label("Pair Apple TV", systemImage: "plus") }
                        .keyboardShortcut("n", modifiers: .command)
                }
            }
        } detail: {
            NavigationStack {
                switch selection {
                case .device(let id):
                    if let device = connection.remoteDevices.first(where: { $0.id == id }) {
                        DeviceDetailView(device: device, connection: connection)
                    } else { MacOverviewView(connection: connection, selection: $selection) }
                case .settings:
                    SettingsView(connection: connection)
                default:
                    MacOverviewView(connection: connection, selection: $selection)
                }
            }
        }
        .navigationSplitViewStyle(.balanced)
        .sheet(isPresented: $showPairing) { PairingView(connection: connection).frame(minWidth: 520, minHeight: 560) }
    }
}

private struct MacDeviceSidebarRow: View {
    let device: ManagedDevice
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "appletv.fill").foregroundStyle(device.connectionStatus == .connected ? .green : .secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(device.name).lineLimit(1)
                Text(device.lockState.isLocked ? "Locked" : device.connectionStatus.label)
                    .font(.caption).foregroundStyle(.secondary)
            }
        }.padding(.vertical, 3)
    }
}

private struct MacOverviewView: View {
    @ObservedObject var connection: ConnectionManager
    @Binding var selection: MacSidebarSelection?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Ciani Device Control").font(.largeTitle.bold())
                    Text("Monitor and manage Apple TVs on your local network.")
                        .font(.title3).foregroundStyle(.secondary)
                }
                HStack(spacing: 14) {
                    metric("Paired", value: connection.remoteDevices.count, symbol: "appletv")
                    metric("Online", value: connection.remoteDevices.filter { $0.connectionStatus == .connected }.count, symbol: "wifi")
                    metric("Locked", value: connection.remoteDevices.filter { $0.lockState.isLocked }.count, symbol: "lock.fill")
                }
                VStack(alignment: .leading, spacing: 12) {
                    Text("Devices").font(.title2.bold())
                    if connection.remoteDevices.isEmpty {
                        ContentUnavailableView("No Paired Devices", systemImage: "appletv",
                            description: Text("Use the + button in the toolbar to pair an Apple TV."))
                            .frame(maxWidth: .infinity, minHeight: 280)
                    } else {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 280), spacing: 16)], spacing: 16) {
                            ForEach(connection.remoteDevices) { device in
                                Button { selection = .device(device.id) } label: {
                                    VStack(alignment: .leading, spacing: 14) {
                                        HStack {
                                            Image(systemName: "appletv.fill").font(.title2)
                                            Spacer(); StatusBadge(status: device.connectionStatus)
                                        }
                                        Text(device.name).font(.headline).lineLimit(1)
                                        Label(device.lockState.isLocked ? "Locked" : "Unlocked",
                                              systemImage: device.lockState.isLocked ? "lock.fill" : "lock.open.fill")
                                            .font(.subheadline).foregroundStyle(.secondary)
                                    }
                                    .padding(20).frame(maxWidth: .infinity, alignment: .leading)
                                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
                                }.buttonStyle(.plain)
                            }
                        }
                    }
                }
            }.padding(34).frame(maxWidth: 1100, alignment: .leading)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Overview")
    }

    private func metric(_ title: String, value: Int, symbol: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: symbol).font(.title2).foregroundStyle(Color.accentColor)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(value)").font(.title2.bold()).monospacedDigit()
                Text(title).font(.caption).foregroundStyle(.secondary)
            }
        }.padding(16).frame(maxWidth: 180, alignment: .leading)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}
#endif
