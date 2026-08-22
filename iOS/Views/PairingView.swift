import SwiftUI
import MultipeerConnectivity

struct PairingView: View {
    @ObservedObject var connection: ConnectionManager
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPeer: MCPeerID?
    @State private var code = ""

    var body: some View {
        NavigationStack {
            List {
                Section("Nearby Apple TVs") {
                    if connection.discoveredDevices.isEmpty {
                        Label("Searching for devices…", systemImage: "antenna.radiowaves.left.and.right")
                    }
                    ForEach(connection.discoveredDevices, id: \.self) { peer in
                        Button {
                            selectedPeer = peer; connection.connect(to: peer)
                        } label: {
                            HStack { Label(peer.displayName, systemImage: "appletv"); Spacer(); if selectedPeer == peer { Image(systemName: "checkmark") } }
                        }
                    }
                }
                if let peer = selectedPeer {
                    Section("Pairing Code") {
                        TextField("Six-digit code", text: $code).keyboardType(.numberPad)
                        Button("Pair with \(peer.displayName)") { connection.pair(with: peer, code: code); dismiss() }
                            .disabled(code.count != 6 || !connection.connectedPeers.contains(peer))
                    }
                }
            }
            .navigationTitle("Pair a Device")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
            .alert("Pairing Failed", isPresented: .constant(connection.lastPairingError != nil)) {
                Button("OK") { connection.lastPairingError = nil }
            } message: { Text(connection.lastPairingError ?? "") }
        }
    }
}
