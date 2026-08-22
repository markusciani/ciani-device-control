import SwiftUI

struct DeviceListView: View {
    @ObservedObject var connection: ConnectionManager
    @State private var showPairing = false

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()
            if connection.remoteDevices.isEmpty {
                ContentUnavailableView("No Paired Devices", systemImage: "appletv",
                    description: Text("Set up Ciani Device Control on an Apple TV, then pair it here."))
            } else {
                ScrollView {
                    LazyVStack(spacing: 14) {
                        ForEach(connection.remoteDevices) { device in
                            NavigationLink(value: device) { DeviceCard(device: device) }.buttonStyle(.plain)
                        }
                    }.padding()
                }
            }
        }
        .navigationTitle("Devices")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Ciani Device Control").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                }
            }
            ToolbarItem(placement: .topBarTrailing) { Button { showPairing = true } label: { Image(systemName: "plus") } }
        }
        .navigationDestination(for: ManagedDevice.self) { DeviceDetailView(device: $0, connection: connection) }
        .sheet(isPresented: $showPairing) { PairingView(connection: connection) }
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
