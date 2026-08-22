import SwiftUI

@main
struct CianiDeviceControlTVApp: App {
    @StateObject private var store: DeviceStateStore
    @StateObject private var connection: ConnectionManager
    @StateObject private var updates = UpdateChecker()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let state = DeviceStateStore()
        _store = StateObject(wrappedValue: state)
        _connection = StateObject(wrappedValue: ConnectionManager(stateStore: state))
    }

    var body: some Scene {
        WindowGroup {
            TVRootView()
                .environmentObject(store)
                .environmentObject(connection)
                .environmentObject(updates)
                .onAppear { connection.start() }
                .task { await updates.check() }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { Task { await updates.check() } }
                }
        }
    }
}
