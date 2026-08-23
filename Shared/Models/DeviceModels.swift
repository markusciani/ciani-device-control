import Foundation

enum ConnectionStatus: String, Codable, CaseIterable, Hashable {
    case connected, offline, searching, pairing

    var label: String { rawValue.capitalized }
    var symbol: String {
        switch self {
        case .connected: "checkmark.circle.fill"
        case .offline: "wifi.slash"
        case .searching: "antenna.radiowaves.left.and.right"
        case .pairing: "link"
        }
    }
}

enum LockState: Codable, Hashable {
    case unlocked
    case lockedIndefinitely
    case lockedUntil(Date)

    var isLocked: Bool {
        switch self { case .unlocked: false; default: true }
    }

    var unlockAt: Date? {
        if case .lockedUntil(let date) = self { date } else { nil }
    }
}

struct ManagedDevice: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var connectionStatus: ConnectionStatus
    var lockState: LockState
    var customMessage: String?
    var lastSeen: Date
    var controllerID: UUID?

    static let preview = ManagedDevice(
        id: UUID(), name: "Living Room Apple TV", connectionStatus: .connected,
        lockState: .lockedUntil(Date().addingTimeInterval(18 * 60 + 42)),
        customMessage: "Device unavailable during rehearsal.", lastSeen: .now
    )
}

enum GradientPreset: String, Codable, CaseIterable, Identifiable {
    case aurora = "Aurora"
    case indigo = "Indigo"
    case ocean = "Ocean"
    case purpleNight = "Purple Night"
    case dynamic = "Dynamic"
    var id: String { rawValue }
}

struct PairingRequest: Codable {
    let code: String
    let controllerID: UUID
    let controllerName: String
    let sharedSecret: String
    let removalPINHash: String?
}

struct DeviceStatusPayload: Codable {
    let device: ManagedDevice
    let gradientPreset: GradientPreset
}

enum DeviceCommand: Codable {
    case pair(PairingRequest)
    case pairAccepted(DeviceStatusPayload)
    case pairRejected
    case lock(unlockAt: Date?, message: String?)
    case unlock
    case systemUnlockRequested(deviceID: UUID, deviceName: String)
    case requestStatus
    case statusResponse(DeviceStatusPayload)
    case renameDevice(String)
    case setGradient(GradientPreset)
    case unpair
    case setRemovalPINHash(String)
    case unpairConfirmed(UUID)
}
