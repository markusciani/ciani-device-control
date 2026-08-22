import SwiftUI

@main
struct CianiDeviceControlApp: App {
    @StateObject private var auth = AuthenticationModel()
    @StateObject private var updates = UpdateChecker()
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL
    @AppStorage("controller-auto-lock") private var autoLock = true

    var body: some Scene {
        WindowGroup {
            Group {
                if auth.isAuthenticated { ControllerRootView().environmentObject(auth).transition(.opacity.combined(with: .scale(scale: 0.98))) }
                else { PINView().environmentObject(auth).transition(.opacity) }
            }
            .animation(.easeInOut(duration: 0.4), value: auth.isAuthenticated)
            .task { await updates.check() }
            .onChange(of: scenePhase) { _, phase in
                if autoLock, phase != .active, auth.isAuthenticated { auth.signOut() }
                if phase == .active { Task { await updates.check() } }
            }
            .alert("Administrator Update Available", isPresented: Binding(
                get: { auth.isAuthenticated && updates.shouldPresentUpdate },
                set: { if !$0 { updates.dismissCurrentNotice() } }
            )) {
                if let url = updates.manifest?.releaseURL {
                    Button("View Update") { openURL(url); updates.dismissCurrentNotice() }
                }
                Button("Later", role: .cancel) { updates.dismissCurrentNotice() }
            } message: {
                Text("Version \(updates.manifest?.latestVersion ?? "") is available. \(updates.manifest?.message ?? "")")
            }
        }
    }
}
