import SwiftUI

struct DeviceListView: View {
    @ObservedObject var connection: ConnectionManager
    @State private var showPairing = false
    @State private var searchText = ""
    @AppStorage("match-controller-theme") private var matchControllerTheme = false
    @AppStorage("gradient-preset") private var presetRaw = GradientPreset.aurora.rawValue

    private var filteredDevices: [ManagedDevice] {
        guard !searchText.isEmpty else { return connection.remoteDevices }
        return connection.remoteDevices.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        ZStack {
            if matchControllerTheme {
                AnimatedGradientBackground(preset: GradientPreset(rawValue: presetRaw) ?? .aurora)
            } else {
                Color(.systemGroupedBackground).ignoresSafeArea()
            }
            if connection.remoteDevices.isEmpty {
                ContentUnavailableView("No Paired Devices", systemImage: "appletv",
                    description: Text("Set up Ciani Device Control on an Apple TV, then pair it here."))
            } else {
                ScrollView {
                    LazyVStack(spacing: 14) {
                        DeviceSummaryStrip(devices: connection.remoteDevices)
                        ForEach(filteredDevices) { device in
                            NavigationLink(value: device) { DeviceCard(device: device) }.buttonStyle(.plain)
                        }
                    }.padding()
                }
            }
        }
        .navigationTitle("Devices")
        .searchable(text: $searchText, prompt: "Search devices")
        .refreshable { connection.refreshStatus() }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Ciani Device Control").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                }
            }
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button { connection.refreshStatus() } label: { Image(systemName: "arrow.clockwise") }
                    .accessibilityLabel("Refresh device status")
                Button { showPairing = true } label: { Image(systemName: "plus") }
                    .accessibilityLabel("Pair Apple TV")
            }
        }
        .navigationDestination(for: ManagedDevice.self) { DeviceDetailView(device: $0, connection: connection) }
        .sheet(isPresented: $showPairing) { PairingView(connection: connection) }
    }
}

private struct DeviceSummaryStrip: View {
    let devices: [ManagedDevice]
    var body: some View {
        HStack(spacing: 10) {
            summary("Online", devices.filter { $0.connectionStatus == .connected }.count, "wifi", .green)
            summary("Locked", devices.filter { $0.lockState.isLocked }.count, "lock.fill", .orange)
            summary("Offline", devices.filter { $0.connectionStatus != .connected }.count, "wifi.slash", .secondary)
        }
    }

    private func summary(_ title: String, _ value: Int, _ symbol: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("\(value)", systemImage: symbol).font(.headline).foregroundStyle(color)
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
    }
}

private struct DeviceCard: View {
    let device: ManagedDevice
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "appletv.fill").font(.title2).frame(width: 52, height: 52)
                .background(Color.accentColor.opacity(0.14), in: RoundedRectangle(cornerRadius: 16))
            VStack(alignment: .leading, spacing: 5) {
                Text(device.name).font(.headline)
                StatusBadge(status: device.connectionStatus)
                Label(lockDescription, systemImage: device.lockState.isLocked ? "lock.fill" : "lock.open.fill")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer(); Image(systemName: "chevron.right").font(.caption.bold()).foregroundStyle(.tertiary)
        }.padding(18).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24))
    }
    private var lockDescription: String {
        if let date = device.lockState.unlockAt { return "Locked · \(CountdownLogic.remaining(until: date).formatted) remaining" }
        return device.lockState.isLocked ? "Locked indefinitely" : "Unlocked"
    }
}
