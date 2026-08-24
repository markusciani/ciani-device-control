import SwiftUI

struct DeviceDetailView: View {
    let device: ManagedDevice
    @ObservedObject var connection: ConnectionManager
    @State private var showTimer = false
    @State private var showRename = false
    @State private var renamedDevice = ""
    @State private var message = ""
    @State private var operationError: String?
    @State private var selectedPreset = GradientPreset.aurora

    private var current: ManagedDevice { connection.remoteDevices.first(where: { $0.id == device.id }) ?? device }

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                Image(systemName: "appletv.fill").font(.system(size: 54)).frame(width: 112, height: 112)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 30))
                Text(current.name).font(.title.bold()).multilineTextAlignment(.center)
                StatusBadge(status: current.connectionStatus)
                VStack(spacing: 10) {
                    Text(current.lockState.isLocked ? "DEVICE LOCKED" : "DEVICE UNLOCKED")
                        .font(.title2.bold()).expandedFont()
                    if let date = current.lockState.unlockAt {
                        TimelineView(.periodic(from: .now, by: 1)) { context in
                            Text(CountdownLogic.remaining(until: date, now: context.date).formatted)
                                .font(.system(size: 48, weight: .bold, design: .rounded)).expandedFont().monospacedDigit()
                        }
                        Text("Unlocks at \(date.formatted(date: .omitted, time: .shortened))").foregroundStyle(.secondary)
                    }
                }.frame(maxWidth: .infinity).padding(24).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 26))

                VStack(spacing: 12) {
                    TextField("Optional lock message", text: $message, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                    HStack {
                        action("Lock Now", "lock.fill", .red) { lock(until: nil) }
                        action("Unlock Now", "lock.open.fill", .green) { unlock() }
                    }
                    .disabled(current.connectionStatus != .connected)
                    Button { showTimer = true } label: {
                        Label(current.lockState.unlockAt == nil ? "Lock for a Duration" : "Change Timer", systemImage: "timer")
                            .frame(maxWidth: .infinity).padding().background(Color.accentColor, in: RoundedRectangle(cornerRadius: 16)).foregroundStyle(.white)
                    }
                    .disabled(current.connectionStatus != .connected)
                    if current.connectionStatus != .connected {
                        Label("Open Ciani Device Control on this Apple TV to use live controls.", systemImage: "wifi.slash")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }

                VStack(alignment: .leading, spacing: 16) {
                    Text("TV Appearance").font(.headline)
                    Picker("Color Theme", selection: $selectedPreset) {
                        ForEach(GradientPreset.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.menu)
                    Button {
                        guard connection.send(.setGradient(selectedPreset), toDeviceID: current.id) else {
                            operationError = "The Apple TV is offline. Open the TV app and try again."
                            return
                        }
                    } label: {
                        Label("Apply Theme to This TV", systemImage: "paintpalette.fill").frame(maxWidth: .infinity)
                    }.buttonStyle(.borderedProminent).disabled(current.connectionStatus != .connected)
                }
                .frame(maxWidth: .infinity, alignment: .leading).padding(20)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22))

                VStack(alignment: .leading, spacing: 12) {
                    Text("Device Information").font(.headline)
                    LabeledContent("Last Seen", value: current.lastSeen.formatted(date: .abbreviated, time: .shortened))
                    LabeledContent("Connection", value: current.connectionStatus.label)
                    ShareLink(item: current.id.uuidString) {
                        LabeledContent("Device ID") {
                            Label("Share", systemImage: "square.and.arrow.up").font(.subheadline)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading).padding(20)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22))
            }.padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Device")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button { connection.refreshStatus(for: current.id) } label: { Image(systemName: "arrow.clockwise") }
                    .disabled(current.connectionStatus != .connected)
                Button("Rename") { renamedDevice = current.name; showRename = true }
                    .disabled(current.connectionStatus != .connected)
            }
        }
        .sheet(isPresented: $showTimer) { LockTimerView(message: message) { date in lock(until: date) } }
        .alert("Command Could Not Be Completed", isPresented: Binding(
            get: { operationError != nil },
            set: { if !$0 { operationError = nil } }
        )) { Button("OK") { operationError = nil } } message: { Text(operationError ?? "Unknown error") }
        .alert("Rename Device", isPresented: $showRename) {
            TextField("Device name", text: $renamedDevice)
            Button("Save") {
                let cleanName = renamedDevice.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !cleanName.isEmpty, connection.send(.renameDevice(cleanName), toDeviceID: current.id) else {
                    operationError = "The name could not be changed because the Apple TV is offline."
                    return
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .onAppear {
            message = current.customMessage ?? ""
            connection.refreshStatus(for: current.id)
        }
    }

    private func lock(until date: Date?) {
        guard current.connectionStatus == .connected else {
            operationError = "The Apple TV is offline. Open Ciani Device Control on the TV and try again."
            return
        }
        Task {
            await connection.lockManagedDevice(current, until: date, message: message)
            #if targetEnvironment(macCatalyst)
            operationError = connection.configuratorBridge.lastError
            #endif
        }
    }

    private func unlock() {
        guard current.connectionStatus == .connected else {
            operationError = "The Apple TV is offline. Open Ciani Device Control on the TV and try again."
            return
        }
        Task {
            await connection.unlockManagedDevice(current)
            #if targetEnvironment(macCatalyst)
            operationError = connection.configuratorBridge.lastError
            #endif
        }
    }

    private func action(_ title: String, _ symbol: String, _ color: Color, perform: @escaping () -> Void) -> some View {
        Button(action: perform) { Label(title, systemImage: symbol).frame(maxWidth: .infinity).padding().background(color.opacity(0.14), in: RoundedRectangle(cornerRadius: 16)) }
    }
}

private struct LockTimerView: View {
    let message: String
    let onSet: (Date) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var selection = 15
    @State private var customHours = 0
    @State private var customMinutes = 30
    @State private var useSpecificTime = false
    @State private var specificTime = Date().addingTimeInterval(3600)
    private let presets = [5, 15, 30, 60]

    var body: some View {
        NavigationStack {
            Form {
                Section("Duration") {
                    Picker("Preset", selection: $selection) {
                        ForEach(presets, id: \.self) { Text($0 == 60 ? "1 hour" : "\($0) minutes").tag($0) }
                        Text("Custom").tag(-1)
                    }
                    if selection == -1 {
                        Stepper("Hours: \(customHours)", value: $customHours, in: 0...23)
                        Stepper("Minutes: \(customMinutes)", value: $customMinutes, in: 0...59)
                    }
                }
                Section("Or unlock at a time") {
                    Toggle("Use Specific Time", isOn: $useSpecificTime)
                    if useSpecificTime { DatePicker("Unlock At", selection: $specificTime, in: Date()...) }
                }
            }
            .navigationTitle("Set Lock Timer")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Set") {
                        let seconds = selection == -1 ? (customHours * 3600 + customMinutes * 60) : selection * 60
                        onSet(useSpecificTime ? specificTime : Date().addingTimeInterval(TimeInterval(seconds))); dismiss()
                    }.disabled(!useSpecificTime && selection == -1 && customHours == 0 && customMinutes == 0)
                }
            }
        }
    }
}
