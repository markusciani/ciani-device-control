import SwiftUI

struct ControllerRootView: View {
    @StateObject private var connection = ConnectionManager()

    var body: some View {
        #if targetEnvironment(macCatalyst)
        MacControllerRootView(connection: connection)
            .onAppear { connection.start() }
        #else
        TabView {
            NavigationStack { DeviceListView(connection: connection) }
                .tabItem { Label("Devices", systemImage: "appletv") }
            NavigationStack { SettingsView(connection: connection) }
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
        .onAppear { connection.start() }
        #endif
    }
}
