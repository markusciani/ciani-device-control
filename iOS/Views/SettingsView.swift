import SwiftUI

struct SettingsView: View {
    @ObservedObject var connection: ConnectionManager
    @EnvironmentObject private var auth: AuthenticationModel
    @AppStorage("animated-background") private var animatedBackground = true
    @AppStorage("controller-auto-lock") private var autoLock = true
    @AppStorage("gradient-preset") private var presetRaw = GradientPreset.aurora.rawValue
    @AppStorage("match-controller-theme") private var matchControllerTheme = false
    @State private var newPIN = ""
    @State private var showPINChange = false
    @State private var pinError: String?

    var body: some View {
        List {
            Section("Security") {
                Button("Change Master PIN") { showPINChange = true }
                Toggle("Use \(auth.biometricName)", isOn: Binding(
                    get: { auth.isFaceIDEnabled },
                    set: { auth.setFaceIDEnabled($0) }
                )).disabled(!auth.canUseFaceID || auth.isAuthenticatingWithFaceID)
                if !auth.canUseFaceID {
                    Label("Biometric authentication is unavailable or not enrolled on this device.", systemImage: auth.biometricSymbol)
                        .font(.caption).foregroundStyle(.secondary)
                }
                Toggle("Auto-Lock Controller", isOn: $autoLock)
            }
            Section("Appearance") {
                Picker("Gradient Style", selection: $presetRaw) {
                    ForEach(GradientPreset.allCases) { Text($0.rawValue).tag($0.rawValue) }
                }.onChange(of: presetRaw) { _, value in if let preset = GradientPreset(rawValue: value) { connection.send(.setGradient(preset)) } }
                Toggle("Animated Background", isOn: $animatedBackground)
                Toggle("Match Controller to TV Colors", isOn: $matchControllerTheme)
                NavigationLink("Lock Screen Preview") { LockScreenPreview(preset: GradientPreset(rawValue: presetRaw) ?? .aurora) }
            }
            Section("Devices") {
                NavigationLink {
                    PairedDeviceManagementView(connection: connection)
                } label: {
                    LabeledContent("Manage Paired Devices", value: "\(connection.remoteDevices.count)")
                }
            }
            Section("About") { LabeledContent("Ciani Device Control", value: "Version \(AppVersion.display)") }
            Section { Button("Lock Master Control", role: .destructive) { auth.signOut() } }
        }.navigationTitle("Settings")
        .onAppear { auth.refreshFaceIDAvailability() }
        .alert("Change Master PIN", isPresented: $showPINChange) {
            TextField("New four-digit PIN", text: $newPIN).keyboardType(.numberPad)
            Button("Save") {
                if auth.changePIN(to: newPIN) {
                    connection.updateRemovalPIN(newPIN)
                    newPIN = ""
                } else {
                    pinError = "The administrator PIN must contain exactly four numbers."
                }
            }
            Button("Cancel", role: .cancel) { newPIN = "" }
        } message: { Text("Enter a new four-digit administrator PIN.") }
        .alert("PIN Was Not Changed", isPresented: Binding(
            get: { pinError != nil }, set: { if !$0 { pinError = nil } }
        )) { Button("OK") { pinError = nil } } message: { Text(pinError ?? "") }
    }
}

private struct PairedDeviceManagementView: View {
    @ObservedObject var connection: ConnectionManager
    @State private var deviceToRemove: ManagedDevice?

    var body: some View {
        List {
            if connection.remoteDevices.isEmpty {
                ContentUnavailableView("No Paired Devices", systemImage: "appletv",
                    description: Text("Pair an Apple TV from the Devices tab."))
            } else {
                Section {
                    ForEach(connection.remoteDevices) { device in
                        HStack(spacing: 14) {
                            Image(systemName: "appletv.fill").foregroundStyle(Color.accentColor)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(device.name).font(.headline)
                                Label(device.connectionStatus.label, systemImage: device.connectionStatus.symbol)
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button(role: .destructive) { deviceToRemove = device } label: {
                                Image(systemName: "trash").frame(width: 38, height: 38)
                            }.buttonStyle(.borderless).accessibilityLabel("Remove \(device.name)")
                        }
                        .swipeActions {
                            Button("Remove", role: .destructive) { deviceToRemove = device }
                        }
                    }
                } footer: {
                    Text("Removing a device clears its pairing relationship. If it is offline, removal completes automatically the next time it appears on the local network.")
                }
            }
        }
        .navigationTitle("Paired Devices")
        .alert("Remove Apple TV?", isPresented: Binding(
            get: { deviceToRemove != nil },
            set: { if !$0 { deviceToRemove = nil } }
        ), presenting: deviceToRemove) { device in
            Button("Remove \(device.name)", role: .destructive) {
                connection.removePairedDevice(id: device.id)
                deviceToRemove = nil
            }
            Button("Cancel", role: .cancel) { deviceToRemove = nil }
        } message: { device in
            Text("This controller will no longer manage \(device.name). The Apple TV will return to its pairing screen.")
        }
    }
}

private struct LockScreenPreview: View {
    let preset: GradientPreset
    @AppStorage("animated-background") private var animatedBackground = true
    var body: some View {
        ZStack {
            AnimatedGradientBackground(preset: preset, animates: animatedBackground)
            VStack(spacing: 16) {
                Image(systemName: "lock.fill").font(.largeTitle).padding(24).background(.ultraThinMaterial, in: Circle())
                Text("DEVICE LOCKED").font(.title.bold()).expandedFont()
                Text("This device is managed by\n© Ciani Device Control").multilineTextAlignment(.center)
                Text("18:42").font(.system(size: 54, weight: .bold, design: .rounded)).expandedFont().monospacedDigit()
                Text("REMAINING").font(.caption.bold()).tracking(2)
            }.padding()
        }.navigationTitle("Preview").navigationBarTitleDisplayMode(.inline)
    }
}
