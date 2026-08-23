#if targetEnvironment(macCatalyst)
import Foundation
import Darwin

@MainActor
final class ConfiguratorBridge: ObservableObject {
    enum BridgeError: LocalizedError {
        case cfgutilMissing
        case profileMissing
        case deviceNotFound(String)
        case invalidResponse
        case commandFailed(String)

        var errorDescription: String? {
            switch self {
            case .cfgutilMissing:
                "Apple Configurator's cfgutil tool is not installed on this Mac."
            case .profileMissing:
                "The bundled Apple TV App Lock profile could not be found."
            case .deviceNotFound(let name):
                "Apple Configurator cannot currently reach \(name). Keep the Mac and Apple TV on the same network and confirm that they are paired."
            case .invalidResponse:
                "Apple Configurator returned an unreadable response."
            case .commandFailed(let detail):
                detail.isEmpty ? "Apple Configurator could not change Single App Mode." : detail
            }
        }
    }

    @Published private(set) var isWorking = false
    @Published private(set) var lastError: String?
    @Published private(set) var systemLockedDeviceIDs: Set<UUID> = []

    private let cfgutilURL = URL(fileURLWithPath: "/usr/local/bin/cfgutil")
    private let profileIdentifier = "org.ciani01.cdc.profile.applock"
    private var scheduledUnlocks: [UUID: Task<Void, Never>] = [:]

    func reportError(_ message: String) {
        lastError = message
    }

    func lock(_ device: ManagedDevice, until unlockAt: Date?) async -> Bool {
        isWorking = true
        lastError = nil
        defer { isWorking = false }

        do {
            let ecid = try await resolveECID(for: device.name)
            guard let profileURL = Bundle.main.url(
                forResource: "Ciani Device Control App Lock",
                withExtension: "mobileconfig"
            ) else { throw BridgeError.profileMissing }

            _ = try await run(["--ecid", ecid, "--format", "JSON", "install-profile", profileURL.path])
            systemLockedDeviceIDs.insert(device.id)
            scheduleUnlock(for: device, ecid: ecid, at: unlockAt)
            return true
        } catch {
            lastError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            return false
        }
    }

    func unlock(_ device: ManagedDevice) async -> Bool {
        isWorking = true
        lastError = nil
        defer { isWorking = false }

        do {
            let ecid = try await resolveECID(for: device.name)
            try await removeProfile(ecid: ecid)
            scheduledUnlocks[device.id]?.cancel()
            scheduledUnlocks[device.id] = nil
            systemLockedDeviceIDs.remove(device.id)
            return true
        } catch {
            lastError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            return false
        }
    }

    private func scheduleUnlock(for device: ManagedDevice, ecid: String, at date: Date?) {
        scheduledUnlocks[device.id]?.cancel()
        guard let date else { return }
        scheduledUnlocks[device.id] = Task { [weak self] in
            let delay = max(0, date.timeIntervalSinceNow)
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled, let self else { return }
            do {
                try await self.removeProfile(ecid: ecid)
                self.systemLockedDeviceIDs.remove(device.id)
                self.scheduledUnlocks[device.id] = nil
            } catch {
                self.lastError = "The countdown ended, but Single App Mode could not be removed: \((error as? LocalizedError)?.errorDescription ?? error.localizedDescription)"
            }
        }
    }

    private func removeProfile(ecid: String) async throws {
        _ = try await run(["--ecid", ecid, "--format", "JSON", "remove-profile", profileIdentifier])
    }

    private func resolveECID(for deviceName: String) async throws -> String {
        let data = try await run(["--format", "JSON", "list"])
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let output = root["Output"] as? [String: Any] else { throw BridgeError.invalidResponse }

        let matches = output.compactMap { ecid, value -> String? in
            guard let details = value as? [String: Any],
                  let name = details["name"] as? String,
                  name.localizedCaseInsensitiveCompare(deviceName) == .orderedSame else { return nil }
            return ecid
        }
        guard let ecid = matches.first else { throw BridgeError.deviceNotFound(deviceName) }
        return ecid
    }

    private func run(_ arguments: [String]) async throws -> Data {
        guard FileManager.default.isExecutableFile(atPath: cfgutilURL.path) else { throw BridgeError.cfgutilMissing }
        return try await Task.detached { [cfgutilURL] in
            let token = UUID().uuidString
            let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent("cdc-cfgutil-\(token).out")
            let errorURL = FileManager.default.temporaryDirectory.appendingPathComponent("cdc-cfgutil-\(token).err")
            defer {
                try? FileManager.default.removeItem(at: outputURL)
                try? FileManager.default.removeItem(at: errorURL)
            }

            var actions: posix_spawn_file_actions_t?
            posix_spawn_file_actions_init(&actions)
            defer { posix_spawn_file_actions_destroy(&actions) }
            posix_spawn_file_actions_addopen(&actions, STDOUT_FILENO, outputURL.path, O_WRONLY | O_CREAT | O_TRUNC, 0o600)
            posix_spawn_file_actions_addopen(&actions, STDERR_FILENO, errorURL.path, O_WRONLY | O_CREAT | O_TRUNC, 0o600)

            let strings = [cfgutilURL.path] + arguments
            let storage = strings.map { strdup($0) }
            defer { storage.forEach { free($0) } }
            var argv = storage + [nil]
            var pid: pid_t = 0
            let spawnResult = posix_spawn(&pid, cfgutilURL.path, &actions, nil, &argv, environ)
            guard spawnResult == 0 else {
                throw BridgeError.commandFailed(String(cString: strerror(spawnResult)))
            }
            var status: Int32 = 0
            waitpid(pid, &status, 0)
            let data = (try? Data(contentsOf: outputURL)) ?? Data()
            let errorData = (try? Data(contentsOf: errorURL)) ?? Data()
            let exitedNormally = (status & 0x7f) == 0
            let exitCode = (status >> 8) & 0xff
            guard exitedNormally, exitCode == 0 else {
                let detail = String(data: errorData.isEmpty ? data : errorData, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                throw BridgeError.commandFailed(detail)
            }
            return data
        }.value
    }
}
#endif
