import SwiftUI

struct DeviceDetailView: View {
    let device: ManagedDevice
    @ObservedObject var connection: ConnectionManager
    @State private var showTimer = false
    @State private var showRename = false
    @State private var renamedDevice = ""
    @State private var message = ""
    @State private var operationError: String?

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
                    Button { showTimer = true } label: {
                        Label(current.lockState.unlockAt == nil ? "Lock for a Duration" : "Change Timer", systemImage: "timer")
                            .frame(maxWidth: .infinity).padding().background(Color.accentColor, in: RoundedRectangle(cornerRadius: 16)).foregroundStyle(.white)
                    }
                }
            }.padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Device")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Rename") { renamedDevice = current.name; showRename = true } } }
        .sheet(isPresented: $showTimer) { LockTimerView(message: message) { date in lock(until: date) } }
        .alert("Single App Mode Failed", isPresented: Binding(
            get: { operationError != nil },
            set: { if !$0 { operationError = nil } }
        )) { Button("OK") { operationError = nil } } message: { Text(operationError ?? "Unknown error") }
        .alert("Rename Device", isPresented: $showRename) {
            TextField("Device name", text: $renamedDevice)
            Button("Save") { connection.send(.renameDevice(renamedDevice), toDeviceID: current.id) }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func lock(until date: Date?) {
        Task {
            await connection.lockManagedDevice(current, until: date, message: message)
            #if targetEnvironment(macCatalyst)
            operationError = connection.configuratorBridge.lastError
            #endif
        }
    }

    private func unlock() {
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
