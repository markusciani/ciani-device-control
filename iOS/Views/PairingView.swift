import SwiftUI
import MultipeerConnectivity

struct PairingView: View {
    @ObservedObject var connection: ConnectionManager
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPeer: MCPeerID?
    @State private var code = ""
    @State private var pairingInProgress = false
    @State private var pairedDeviceIDs: Set<UUID> = []

    var body: some View {
        NavigationStack {
            List {
                Section("Nearby Apple TVs") {
                    if connection.discoveredDevices.isEmpty {
                        Label("Searching for devices…", systemImage: "antenna.radiowaves.left.and.right")
                    }
                    ForEach(connection.discoveredDevices, id: \.self) { peer in
                        Button {
                            selectedPeer = peer
                            code = ""
                            pairingInProgress = false
                            connection.lastPairingError = nil
                            connection.connect(to: peer)
                        } label: {
                            HStack { Label(peer.displayName, systemImage: "appletv"); Spacer(); if selectedPeer == peer { Image(systemName: "checkmark") } }
                        }
                    }
                }
                if let peer = selectedPeer {
                    Section("Pairing Code") {
                        TextField("Six-digit code", text: $code)
                            .keyboardType(.numberPad)
                            .onChange(of: code) { _, value in
                                code = String(value.filter(\.isNumber).prefix(6))
                            }
                        Button {
                            pairingInProgress = true
                            connection.lastPairingError = nil
                            connection.pair(with: peer, code: code)
                        } label: {
                            HStack {
                                if pairingInProgress { ProgressView().controlSize(.small) }
                                Text(pairingInProgress ? "Pairing…" : "Pair with \(peer.displayName)")
                            }.frame(maxWidth: .infinity)
                        }
                        .disabled(code.count != 6 || !connection.connectedPeers.contains(peer) || pairingInProgress)
                        if !connection.connectedPeers.contains(peer) {
                            Label("Connecting securely to the Apple TV…", systemImage: "wifi")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Pair a Device")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
            .onAppear { pairedDeviceIDs = Set(connection.remoteDevices.map(\.id)) }
            .onChange(of: connection.remoteDevices) { _, devices in
                if devices.contains(where: { !pairedDeviceIDs.contains($0.id) }) { dismiss() }
            }
            .onChange(of: connection.lastPairingError) { _, error in
                if error != nil { pairingInProgress = false }
            }
            .alert("Pairing Failed", isPresented: Binding(
                get: { connection.lastPairingError != nil },
                set: { if !$0 { connection.lastPairingError = nil } }
            )) {
                Button("Try Again") { connection.lastPairingError = nil; pairingInProgress = false }
            } message: { Text(connection.lastPairingError ?? "") }
        }
    }
}
