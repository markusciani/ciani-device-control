import Foundation
import MultipeerConnectivity
import SwiftUI
#if os(iOS)
import UIKit
#elseif os(tvOS)
import UIKit
#endif

@MainActor
final class ConnectionManager: NSObject, ObservableObject {
    static let serviceType = "ciani-control"

    @Published private(set) var discoveredDevices: [MCPeerID] = []
    @Published private(set) var connectedPeers: [MCPeerID] = []
    @Published private(set) var remoteDevices: [ManagedDevice]
    @Published var lastPairingError: String?
    #if targetEnvironment(macCatalyst)
    let configuratorBridge = ConfiguratorBridge()
    #endif

    let localPeer: MCPeerID
    nonisolated(unsafe) private let session: MCSession
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?
    private weak var stateStore: DeviceStateStore?
    private let controllerID: UUID
    private var secretsByPeer: [MCPeerID: String] = [:]
    private var discoveredDeviceIDs: [MCPeerID: UUID] = [:]
    private var peerByDeviceID: [UUID: MCPeerID] = [:]
    private let pairedDevicesKey = "paired-device-metadata"
    private let pendingRemovalKey = "pending-device-removals"
    private let revokedDevicesKey = "revoked-device-ids"
    private var syncedPairingRefreshTask: Task<Void, Never>?

    init(stateStore: DeviceStateStore? = nil) {
        let name = UIDevice.current.name
        self.localPeer = MCPeerID(displayName: String(name.prefix(40)))
        self.session = MCSession(peer: localPeer, securityIdentity: nil, encryptionPreference: .required)
        self.stateStore = stateStore
        #if os(iOS)
        let localSaved = UserDefaults.standard.data(forKey: pairedDevicesKey)
            .flatMap { try? JSONDecoder().decode([ManagedDevice].self, from: $0) } ?? []
        let syncedSaved = SecureStore.get(pairedDevicesKey)
            .flatMap { $0.data(using: .utf8) }
            .flatMap { try? JSONDecoder().decode([ManagedDevice].self, from: $0) } ?? []
        var mergedByID: [UUID: ManagedDevice] = [:]
        for device in syncedSaved { mergedByID[device.id] = device }
        for device in localSaved { mergedByID[device.id] = device }
        if !mergedByID.isEmpty {
            var saved = Array(mergedByID.values)
            let revoked = Set((UserDefaults.standard.array(forKey: revokedDevicesKey) as? [String] ?? []).compactMap(UUID.init(uuidString:)))
            saved.removeAll { revoked.contains($0.id) }
            for index in saved.indices { saved[index].connectionStatus = .offline }
            remoteDevices = saved
        } else { remoteDevices = [] }
        #else
        remoteDevices = []
        #endif
        if let id = UserDefaults.standard.string(forKey: "controller-id").flatMap(UUID.init(uuidString:)) {
            controllerID = id
        } else {
            let id = UUID(); controllerID = id
            UserDefaults.standard.set(id.uuidString, forKey: "controller-id")
        }
        super.init()
        session.delegate = self
        #if os(iOS)
        if !remoteDevices.isEmpty { persistPairedDevices() }
        #endif
    }

    func start() {
        #if os(tvOS)
        let info = ["id": stateStore?.device.id.uuidString ?? UUID().uuidString,
                    "name": stateStore?.device.name ?? "Apple TV"]
        advertiser = MCNearbyServiceAdvertiser(peer: localPeer, discoveryInfo: info, serviceType: Self.serviceType)
        advertiser?.delegate = self
        advertiser?.startAdvertisingPeer()
        #elseif os(iOS)
        browser = MCNearbyServiceBrowser(peer: localPeer, serviceType: Self.serviceType)
        browser?.delegate = self
        browser?.startBrowsingForPeers()
        refreshSyncedPairings()
        #if targetEnvironment(macCatalyst)
        Task { await refreshConfiguratorDevices() }
        #endif
        syncedPairingRefreshTask?.cancel()
        syncedPairingRefreshTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(5))
                guard !Task.isCancelled else { return }
                self?.refreshSyncedPairings()
                #if targetEnvironment(macCatalyst)
                await self?.refreshConfiguratorDevices()
                #endif
            }
        }
        #endif
    }

    func stop() {
        syncedPairingRefreshTask?.cancel()
        advertiser?.stopAdvertisingPeer()
        browser?.stopBrowsingForPeers()
        session.disconnect()
    }

    #if os(iOS)
    func lockManagedDevice(_ device: ManagedDevice, until date: Date?, message: String?) async {
        #if targetEnvironment(macCatalyst)
        guard await configuratorBridge.lock(device, until: date) else { return }
        let connected = await waitForConnection(to: device.id, timeout: 15)
        guard connected, send(.lock(unlockAt: date, message: message), toDeviceID: device.id) else {
            _ = await configuratorBridge.unlock(device)
            configuratorBridge.reportError("Single App Mode opened the TV app, but the Mac could not authenticate with it. The profile was removed for safety. Open the updated TV app once and confirm iCloud Keychain is enabled on the controllers.")
            return
        }
        #else
        send(.lock(unlockAt: date, message: message), toDeviceID: device.id)
        #endif
    }

    func unlockManagedDevice(_ device: ManagedDevice) async {
        #if targetEnvironment(macCatalyst)
        send(.unlock, toDeviceID: device.id)
        guard await configuratorBridge.stopSingleAppMode(deviceNamed: device.name) else { return }
        #else
        send(.unlock, toDeviceID: device.id)
        #endif
    }

    func updateRemovalPIN(_ pin: String) {
        send(.setRemovalPINHash(PINVerifier.hash(pin)))
    }

    private func waitForConnection(to deviceID: UUID, timeout: TimeInterval) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if let peer = peerByDeviceID[deviceID], session.connectedPeers.contains(peer) { return true }
            try? await Task.sleep(for: .milliseconds(300))
        }
        return false
    }

    private func refreshSyncedPairings() {
        guard let value = SecureStore.get(pairedDevicesKey),
              let data = value.data(using: .utf8),
              let synced = try? JSONDecoder().decode([ManagedDevice].self, from: data) else { return }
        let revoked = revokedDeviceIDs
        for var device in synced where !revoked.contains(device.id) {
            if let index = remoteDevices.firstIndex(where: { $0.id == device.id }) {
                if remoteDevices[index].connectionStatus != .connected {
                    device.connectionStatus = .offline
                    remoteDevices[index] = device
                }
            } else {
                device.connectionStatus = .offline
                remoteDevices.append(device)
            }
        }
        for (peer, id) in discoveredDeviceIDs where SecureStore.get("peer-\(id.uuidString)") != nil {
            if !session.connectedPeers.contains(peer) { connect(to: peer) }
        }
    }

    #if targetEnvironment(macCatalyst)
    private func refreshConfiguratorDevices() async {
        let devices = await configuratorBridge.discoverDevices()
        for item in devices where !remoteDevices.contains(where: { $0.name.localizedCaseInsensitiveCompare(item.name) == .orderedSame }) {
            remoteDevices.append(ManagedDevice(
                id: item.id,
                name: item.name,
                connectionStatus: .offline,
                lockState: .unlocked,
                customMessage: nil,
                lastSeen: .now,
                controllerID: nil
            ))
        }
    }
    #endif
    #endif

    #if os(iOS)
    func connect(to peer: MCPeerID) {
        let context = discoveredDeviceIDs[peer]
            .flatMap { SecureStore.get("peer-\($0.uuidString)") }
            .flatMap { $0.data(using: .utf8) }
        browser?.invitePeer(peer, to: session, withContext: context, timeout: 20)
    }

    func pair(with peer: MCPeerID, code: String) {
        let secret = UUID().uuidString + UUID().uuidString
        secretsByPeer[peer] = secret
        let pin = SecureStore.get("master-pin") ?? "2010"
        send(.pair(PairingRequest(code: code, controllerID: controllerID,
                                  controllerName: localPeer.displayName, sharedSecret: secret,
                                  removalPINHash: PINVerifier.hash(pin))), to: [peer])
    }

    func send(_ command: DeviceCommand, to peer: MCPeerID? = nil) {
        let peers = peer.map { [$0] } ?? session.connectedPeers
        send(command, to: peers)
    }

    @discardableResult
    func send(_ command: DeviceCommand, toDeviceID deviceID: UUID) -> Bool {
        guard let peer = peerByDeviceID[deviceID], session.connectedPeers.contains(peer) else { return false }
        send(command, to: [peer])
        return true
    }

    func removePairedDevice(id: UUID) {
        var revoked = revokedDeviceIDs
        revoked.insert(id)
        saveRevokedDeviceIDs(revoked)
        remoteDevices.removeAll { $0.id == id }
        persistPairedDevices()
        if let peer = peerByDeviceID[id], session.connectedPeers.contains(peer) {
            send(.unpair, to: [peer])
            finalizeRemoval(id: id)
        } else {
            var pending = pendingRemovalIDs
            pending.insert(id)
            savePendingRemovalIDs(pending)
        }
    }

    private func forgetRemoteDevice(id: UUID) {
        remoteDevices.removeAll { $0.id == id }
        peerByDeviceID[id] = nil
        SecureStore.delete("peer-\(id.uuidString)")
        persistPairedDevices()
    }
    #endif

    #if os(tvOS)
    func requestSystemUnlock() {
        guard let store = stateStore, store.isPaired else { return }
        send(.systemUnlockRequested(deviceID: store.device.id, deviceName: store.device.name),
             to: session.connectedPeers)
    }

    @discardableResult
    func disconnectFromController(pin: String) -> Bool {
        guard let store = stateStore, store.verifyRemovalPIN(pin) else { return false }
        send(.unpairConfirmed(store.device.id), to: session.connectedPeers)
        store.unpair()
        Task {
            try? await Task.sleep(for: .milliseconds(500))
            session.disconnect()
        }
        return true
    }
    #endif

    private func send(_ command: DeviceCommand, to peers: [MCPeerID]) {
        guard !peers.isEmpty, let data = try? JSONEncoder().encode(command) else { return }
        try? session.send(data, toPeers: peers, with: .reliable)
    }

    private func receive(_ command: DeviceCommand, from peer: MCPeerID) {
        #if os(tvOS)
        guard let store = stateStore else { return }
        if case .pair = command {
            // Pairing is the only command accepted before authorization.
        } else {
            guard store.isPaired else { return }
        }
        switch command {
        case .pair(let request):
            guard request.code == store.pairingCode else { send(.pairRejected, to: [peer]); return }
            store.pair(controllerID: request.controllerID, secret: request.sharedSecret)
            if let hash = request.removalPINHash { store.setRemovalPINHash(hash) }
            send(.pairAccepted(store.statusPayload()), to: [peer])
        case .lock(let date, let message): store.lock(until: date, message: message); send(.statusResponse(store.statusPayload()), to: [peer])
        case .unlock:
            store.unlock()
            send(.statusResponse(store.statusPayload()), to: [peer])
            // An iPhone cannot remove system Single App Mode itself. Relay the
            // request to any connected Mac controller, which can ask the paired
            // Apple Configurator installation to stop it.
            send(.systemUnlockRequested(deviceID: store.device.id, deviceName: store.device.name),
                 to: session.connectedPeers.filter { $0 != peer })
        case .requestStatus: send(.statusResponse(store.statusPayload()), to: [peer])
        case .renameDevice(let name): store.rename(name); send(.statusResponse(store.statusPayload()), to: [peer])
        case .setGradient(let preset): store.gradientPreset = preset; send(.statusResponse(store.statusPayload()), to: [peer])
        case .unpair: store.unpair()
        case .setRemovalPINHash(let hash): store.setRemovalPINHash(hash)
        default: break
        }
        #elseif os(iOS)
        switch command {
        case .pairAccepted(let payload):
            var revoked = revokedDeviceIDs
            revoked.remove(payload.device.id)
            saveRevokedDeviceIDs(revoked)
            var pending = pendingRemovalIDs
            pending.remove(payload.device.id)
            savePendingRemovalIDs(pending)
            peerByDeviceID[payload.device.id] = peer
            upsert(payload.device)
            if let secret = secretsByPeer[peer] {
                SecureStore.set(secret, for: "peer-\(payload.device.id.uuidString)")
            }
        case .statusResponse(let payload):
            if revokedDeviceIDs.contains(payload.device.id) {
                send(.unpair, to: [peer])
                finalizeRemoval(id: payload.device.id)
                return
            }
            peerByDeviceID[payload.device.id] = peer
            upsert(payload.device)
        case .pairRejected: lastPairingError = "The pairing code was not accepted."
        case .unpairConfirmed(let deviceID): forgetRemoteDevice(id: deviceID)
        case .systemUnlockRequested(_, let deviceName):
            #if targetEnvironment(macCatalyst)
            Task { await configuratorBridge.stopSingleAppMode(deviceNamed: deviceName) }
            #endif
        default: break
        }
        #endif
    }

    private func upsert(_ device: ManagedDevice) {
        if let index = remoteDevices.firstIndex(where: { $0.id == device.id }) { remoteDevices[index] = device }
        else { remoteDevices.append(device) }
        persistPairedDevices()
    }

    private func persistPairedDevices() {
        #if os(iOS)
        if let data = try? JSONEncoder().encode(remoteDevices) {
            UserDefaults.standard.set(data, forKey: pairedDevicesKey)
            if let value = String(data: data, encoding: .utf8) {
                SecureStore.set(value, for: pairedDevicesKey)
            }
        }
        #endif
    }

    private var pendingRemovalIDs: Set<UUID> {
        Set((UserDefaults.standard.array(forKey: pendingRemovalKey) as? [String] ?? []).compactMap(UUID.init(uuidString:)))
    }

    private func savePendingRemovalIDs(_ ids: Set<UUID>) {
        UserDefaults.standard.set(ids.map(\.uuidString), forKey: pendingRemovalKey)
    }

    private var revokedDeviceIDs: Set<UUID> {
        Set((UserDefaults.standard.array(forKey: revokedDevicesKey) as? [String] ?? []).compactMap(UUID.init(uuidString:)))
    }

    private func saveRevokedDeviceIDs(_ ids: Set<UUID>) {
        UserDefaults.standard.set(ids.map(\.uuidString), forKey: revokedDevicesKey)
    }

    private func finalizeRemoval(id: UUID) {
        remoteDevices.removeAll { $0.id == id }
        peerByDeviceID[id] = nil
        SecureStore.delete("peer-\(id.uuidString)")
        var pending = pendingRemovalIDs
        pending.remove(id)
        savePendingRemovalIDs(pending)
        persistPairedDevices()
    }
}

extension ConnectionManager: MCSessionDelegate {
    nonisolated func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        Task { @MainActor in
            connectedPeers = session.connectedPeers
            #if os(tvOS)
            stateStore?.updateConnection(state == .connected ? .connected : .offline)
            #elseif os(iOS)
            if state == .connected {
                let pin = SecureStore.get("master-pin") ?? "2010"
                send(.setRemovalPINHash(PINVerifier.hash(pin)), to: [peerID])
                if let id = discoveredDeviceIDs[peerID], pendingRemovalIDs.contains(id) {
                    send(.unpair, to: [peerID]); finalizeRemoval(id: id)
                } else { send(.requestStatus, to: [peerID]) }
            }
            #endif
        }
    }

    nonisolated func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        guard let command = try? JSONDecoder().decode(DeviceCommand.self, from: data) else { return }
        Task { @MainActor in receive(command, from: peerID) }
    }
    nonisolated func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    nonisolated func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    nonisolated func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

extension ConnectionManager: MCNearbyServiceAdvertiserDelegate {
    nonisolated func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        Task { @MainActor in
            let suppliedSecret = context.flatMap { String(data: $0, encoding: .utf8) }
            let accepted = stateStore?.authorizedSecret.map { $0 == suppliedSecret } ?? true
            invitationHandler(accepted, accepted ? session : nil)
        }
    }
}

extension ConnectionManager: MCNearbyServiceBrowserDelegate {
    nonisolated func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        Task { @MainActor in
            if let rawID = info?["id"], let id = UUID(uuidString: rawID) {
                discoveredDeviceIDs[peerID] = id
                peerByDeviceID[id] = peerID
                if let name = info?["name"] {
                    for device in remoteDevices where device.name.localizedCaseInsensitiveCompare(name) == .orderedSame {
                        peerByDeviceID[device.id] = peerID
                    }
                }
                #if os(iOS)
                if let secret = SecureStore.get("peer-\(id.uuidString)") {
                    SecureStore.set(secret, for: "peer-\(id.uuidString)")
                    connect(to: peerID)
                }
                #endif
            }
            if !discoveredDevices.contains(peerID) { discoveredDevices.append(peerID) }
        }
    }
    nonisolated func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        Task { @MainActor in
            discoveredDevices.removeAll { $0 == peerID }
            if let id = discoveredDeviceIDs[peerID],
               let index = remoteDevices.firstIndex(where: { $0.id == id }) {
                remoteDevices[index].connectionStatus = .offline
                persistPairedDevices()
            }
        }
    }
}
