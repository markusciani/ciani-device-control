import Foundation
import SwiftUI

@MainActor
final class DeviceStateStore: ObservableObject {
    @Published private(set) var device: ManagedDevice
    @Published var gradientPreset: GradientPreset { didSet { persist() } }
    @Published private(set) var pairingCode = DeviceStateStore.makePairingCode()
    @Published private(set) var authorizedSecret: String?

    private let defaults: UserDefaults
    private let deviceKey = "managed-device"
    private let presetKey = "gradient-preset"
    private let secretKey = "authorized-secret"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: deviceKey), let saved = try? JSONDecoder().decode(ManagedDevice.self, from: data) {
            device = saved
        } else {
            device = ManagedDevice(id: UUID(), name: "Apple TV", connectionStatus: .offline,
                                   lockState: .unlocked, lastSeen: .now)
        }
        gradientPreset = GradientPreset(rawValue: defaults.string(forKey: presetKey) ?? "") ?? .aurora
        authorizedSecret = defaults.string(forKey: secretKey)
        normalizeExpiredLock()
    }

    var isPaired: Bool { authorizedSecret != nil }

    func pair(controllerID: UUID, secret: String) {
        authorizedSecret = secret
        device.controllerID = controllerID
        device.connectionStatus = .connected
        defaults.set(secret, forKey: secretKey)
        persist()
    }

    func unpair() {
        authorizedSecret = nil
        device.controllerID = nil
        device.connectionStatus = .offline
        device.lockState = .unlocked
        device.customMessage = nil
        pairingCode = Self.makePairingCode()
        defaults.removeObject(forKey: secretKey)
        persist()
    }

    func lock(until: Date?, message: String?) {
        device.lockState = until.map(LockState.lockedUntil) ?? .lockedIndefinitely
        device.customMessage = message?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        persist()
    }

    func unlock() { device.lockState = .unlocked; device.customMessage = nil; persist() }
    func rename(_ name: String) { if !name.isEmpty { device.name = name; persist() } }
    func updateConnection(_ status: ConnectionStatus) { device.connectionStatus = status; device.lastSeen = .now; persist() }

    func normalizeExpiredLock(now: Date = .now) {
        if let date = device.lockState.unlockAt, date <= now { unlock() }
    }

    func statusPayload() -> DeviceStatusPayload { DeviceStatusPayload(device: device, gradientPreset: gradientPreset) }

    private func persist() {
        defaults.set(try? JSONEncoder().encode(device), forKey: deviceKey)
        defaults.set(gradientPreset.rawValue, forKey: presetKey)
    }

    private static func makePairingCode() -> String { String(format: "%06d", Int.random(in: 0...999_999)) }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
