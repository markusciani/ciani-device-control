#if targetEnvironment(macCatalyst)
import Foundation
import Darwin
import CryptoKit

@MainActor
final class ConfiguratorBridge: ObservableObject {
    struct ConfiguratorDevice: Sendable {
        let id: UUID
        let ecid: String
        let name: String
    }
    enum BridgeError: LocalizedError {
        case cfgutilMissing
        case deviceNotFound(String)
        case ambiguousDevice(String)
        case invalidResponse
        case commandFailed(String)

        var errorDescription: String? {
            switch self {
            case .cfgutilMissing:
                "Apple Configurator's cfgutil tool is not installed on this Mac."
            case .deviceNotFound(let name):
                "Apple Configurator cannot currently reach \(name). Keep the Mac and Apple TV on the same network and confirm that they are paired."
            case .ambiguousDevice(let name):
                "More than one Apple TV is named \(name). Rename one before using automatic unlock."
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
    private var scheduledUnlocks: [UUID: Task<Void, Never>] = [:]

    func reportError(_ message: String) {
        lastError = message
    }

    func discoverDevices() async -> [ConfiguratorDevice] {
        do {
            let data = try await run(["--format", "JSON", "list"])
            guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let output = root["Output"] as? [String: Any] else { return [] }
            return output.compactMap { ecid, value in
                guard let details = value as? [String: Any], let name = details["name"] as? String else { return nil }
                return ConfiguratorDevice(id: Self.stableID(for: ecid), ecid: ecid, name: name)
            }
        } catch {
            lastError = permissionAwareMessage(for: error, operation: "lock")
            return []
        }
    }

    func lock(_ device: ManagedDevice, until unlockAt: Date?) async -> Bool {
        isWorking = true
        lastError = nil
        defer { isWorking = false }

        do {
            // cfgutil cannot install an autonomous App Lock profile on recent
            // tvOS releases (DMCInstallationErrorDomain 4020). Configurator's
            // own Start Single App Mode action is the supported local workflow.
            let ecid = try await resolveECID(for: device.name)
            try await runAppleScript(Self.startSingleAppModeScript, replacements: [
                "__DEVICE_NAME__": device.name,
                "__DEVICE_ECID__": ecid,
                "__APP_NAME__": "Ciani Device Control",
                "__BUNDLE_ID__": "org.ciani01.cdctv"
            ])
            systemLockedDeviceIDs.insert(device.id)
            scheduleUnlock(for: device, at: unlockAt)
            return true
        } catch {
            lastError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            return false
        }
    }

    func unlock(_ device: ManagedDevice) async -> Bool {
        await stopSingleAppMode(deviceNamed: device.name)
    }

    func stopSingleAppMode(deviceNamed deviceName: String) async -> Bool {
        isWorking = true
        lastError = nil
        defer { isWorking = false }

        do {
            // Resolve first so UI automation is never allowed to operate on an
            // absent or ambiguously named device.
            let ecid = try await resolveECID(for: deviceName)
            try await runAppleScript(Self.stopSingleAppModeScript, replacements: [
                "__DEVICE_NAME__": deviceName,
                "__DEVICE_ECID__": ecid
            ])
            return true
        } catch {
            lastError = permissionAwareMessage(for: error, operation: "unlock")
            return false
        }
    }

    private func permissionAwareMessage(for error: Error, operation: String) -> String {
        let detail = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        if detail.localizedCaseInsensitiveContains("not authorized") ||
            detail.localizedCaseInsensitiveContains("not allowed assistive access") ||
            detail.localizedCaseInsensitiveContains("accessibility") ||
            detail.localizedCaseInsensitiveContains("-1719") ||
            detail.localizedCaseInsensitiveContains("-1743") ||
            detail.localizedCaseInsensitiveContains("-25211") {
            return "Automatic \(operation) needs permission on this Mac. In System Settings > Privacy & Security, enable Ciani Device Control under Accessibility and Automation, then quit and reopen Ciani Device Control."
        }
        return detail
    }

    private func scheduleUnlock(for device: ManagedDevice, at date: Date?) {
        scheduledUnlocks[device.id]?.cancel()
        guard let date else { return }
        scheduledUnlocks[device.id] = Task { [weak self] in
            let delay = max(0, date.timeIntervalSinceNow)
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled, let self else { return }
            let unlocked = await self.stopSingleAppMode(deviceNamed: device.name)
            if unlocked {
                self.systemLockedDeviceIDs.remove(device.id)
                self.scheduledUnlocks[device.id] = nil
            } else {
                let detail = self.lastError ?? "Apple Configurator did not complete the request."
                self.lastError = "The countdown ended, but Single App Mode could not be removed: \(detail)"
            }
        }
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
        guard !matches.isEmpty else { throw BridgeError.deviceNotFound(deviceName) }
        guard matches.count == 1, let ecid = matches.first else { throw BridgeError.ambiguousDevice(deviceName) }
        return ecid
    }

    private static func stableID(for value: String) -> UUID {
        let digest = SHA256.hash(data: Data("configurator:\(value)".utf8))
        var bytes = Array(digest.prefix(16))
        bytes[6] = (bytes[6] & 0x0f) | 0x50
        bytes[8] = (bytes[8] & 0x3f) | 0x80
        return UUID(uuid: (bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
                          bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]))
    }

    private func run(_ arguments: [String]) async throws -> Data {
        guard FileManager.default.isExecutableFile(atPath: cfgutilURL.path) else { throw BridgeError.cfgutilMissing }
        return try await runExecutable(cfgutilURL, arguments: arguments)
    }

    private func runExecutable(_ executableURL: URL, arguments: [String]) async throws -> Data {
        guard FileManager.default.isExecutableFile(atPath: executableURL.path) else {
            throw BridgeError.commandFailed("Required macOS tool is unavailable: \(executableURL.path)")
        }
        return try await Task.detached {
            let token = UUID().uuidString
            let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent("cdc-command-\(token).out")
            let errorURL = FileManager.default.temporaryDirectory.appendingPathComponent("cdc-command-\(token).err")
            defer {
                try? FileManager.default.removeItem(at: outputURL)
                try? FileManager.default.removeItem(at: errorURL)
            }

            var actions: posix_spawn_file_actions_t?
            posix_spawn_file_actions_init(&actions)
            defer { posix_spawn_file_actions_destroy(&actions) }
            posix_spawn_file_actions_addopen(&actions, STDOUT_FILENO, outputURL.path, O_WRONLY | O_CREAT | O_TRUNC, 0o600)
            posix_spawn_file_actions_addopen(&actions, STDERR_FILENO, errorURL.path, O_WRONLY | O_CREAT | O_TRUNC, 0o600)

            let strings = [executableURL.path] + arguments
            let storage = strings.map { strdup($0) }
            defer { storage.forEach { free($0) } }
            var argv = storage + [nil]
            var pid: pid_t = 0
            let spawnResult = posix_spawn(&pid, executableURL.path, &actions, nil, &argv, environ)
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

    private func runAppleScript(_ source: String, replacements: [String: String]) async throws {
        let rendered = replacements.reduce(source) { result, pair in
            result.replacingOccurrences(of: pair.key, with: Self.appleScriptLiteral(pair.value))
        }
        try await Task.detached {
            var errorInfo: NSDictionary?
            guard let script = NSAppleScript(source: rendered) else {
                throw BridgeError.commandFailed("The Configurator automation could not be prepared.")
            }
            script.executeAndReturnError(&errorInfo)
            if let errorInfo {
                let message = (errorInfo["NSAppleScriptErrorMessage"] as? String)
                    ?? (errorInfo["NSAppleScriptErrorBriefMessage"] as? String)
                    ?? "Apple Configurator automation failed."
                throw BridgeError.commandFailed(message)
            }
        }.value
    }

    private static func appleScriptLiteral(_ value: String) -> String {
        "\"" + value.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"") + "\""
    }

    private static let startSingleAppModeScript = #"""
        set targetName to __DEVICE_NAME__
        set targetECID to __DEVICE_ECID__
        set targetAppName to __APP_NAME__
        set targetBundleID to __BUNDLE_ID__
        tell application "Apple Configurator" to activate
        delay 1

        tell application "System Events"
            tell process "Apple Configurator"
                set frontmost to true
                -- Command-F focuses Configurator's device filter even when its
                -- toolbar field is not exposed through Accessibility. Filtering
                -- by ECID leaves exactly the cfgutil-verified target visible.
                keystroke "f" using command down
                delay 0.3
                keystroke "a" using command down
                keystroke targetECID
                delay 0.7
                key code 48
                delay 0.2
                keystroke "a" using command down
                delay 0.5

                click menu bar item "Actions" of menu bar 1
                delay 0.2
                click menu item "Advanced" of menu 1 of menu bar item "Actions" of menu bar 1
                delay 0.2
                set advancedMenu to menu 1 of menu item "Advanced" of menu 1 of menu bar item "Actions" of menu bar 1
                set startItems to menu items of advancedMenu whose name starts with "Start Single App Mode"
                if (count of startItems) is not 1 then error "Start Single App Mode is unavailable. Confirm this Apple TV is supervised and connected to Apple Configurator."
                click item 1 of startItems
                delay 1

                set chooser to front window
                try
                    if (count of sheets of front window) > 0 then set chooser to sheet 1 of front window
                end try

                -- Filter the installed-app list when Configurator exposes a search field.
                try
                    set value of text field 1 of chooser to targetAppName
                    delay 0.5
                end try

                set appItems to {}
                repeat with candidate in entire contents of chooser
                    try
                        set candidateValue to value of candidate as text
                        if candidateValue is targetAppName or candidateValue is targetBundleID then set end of appItems to candidate
                    end try
                    try
                        set candidateTitle to title of candidate as text
                        if candidateTitle is targetAppName or candidateTitle is targetBundleID then set end of appItems to candidate
                    end try
                end repeat
                if (count of appItems) is 0 then error "Ciani Device Control is not installed on this Apple TV. Install it, reopen Configurator, and try again."

                set appItem to item 1 of appItems
                try
                    perform action "AXPress" of appItem
                on error
                    click appItem
                end try
                delay 0.3

                set selectButtons to buttons of chooser whose name is "Select App"
                if (count of selectButtons) is 0 then set selectButtons to buttons of chooser whose name is "Select"
                if (count of selectButtons) is 0 then error "Configurator opened the app chooser, but the Select App button could not be found."
                click item 1 of selectButtons
            end tell
        end tell
    """#

    private static let stopSingleAppModeScript = #"""
        set targetName to __DEVICE_NAME__
        set targetECID to __DEVICE_ECID__
        tell application "Apple Configurator" to activate
        delay 1

        tell application "System Events"
            tell process "Apple Configurator"
                set frontmost to true
                keystroke "f" using command down
                delay 0.3
                keystroke "a" using command down
                keystroke targetECID
                delay 0.7
                key code 48
                delay 0.2
                keystroke "a" using command down
                delay 0.5

                click menu bar item "Actions" of menu bar 1
                delay 0.2
                click menu item "Advanced" of menu 1 of menu bar item "Actions" of menu bar 1
                delay 0.2
                set advancedMenu to menu 1 of menu item "Advanced" of menu 1 of menu bar item "Actions" of menu bar 1
                set stopItems to menu items of advancedMenu whose name starts with "Stop Single App Mode"
                if (count of stopItems) is not 1 then error "Stop Single App Mode is unavailable. Confirm the selected Apple TV is currently locked."
                click item 1 of stopItems
            end tell
        end tell
    """#
}
#endif
