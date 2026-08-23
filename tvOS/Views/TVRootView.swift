import SwiftUI

struct TVBrandHeader: View {
    @EnvironmentObject private var store: DeviceStateStore
    var body: some View {
        VStack(alignment: .center, spacing: 3) {
            Text(store.device.name).font(.system(size: 28, weight: .semibold)).lineLimit(1)
            Text("Version \(AppVersion.display)").font(.system(size: 18, weight: .medium)).foregroundStyle(.white.opacity(0.68))
        }
        .multilineTextAlignment(.center)
        .foregroundStyle(.white)
        .shadow(color: .black.opacity(0.7), radius: 8, y: 2)
        .padding(.top, 52)
    }
}

struct TVRootView: View {
    @EnvironmentObject private var store: DeviceStateStore
    @EnvironmentObject private var updates: UpdateChecker
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showingUnlockTransition = false

    var body: some View {
        Group {
            if showingUnlockTransition { TVUnlockTransitionView() }
            else if !store.isPaired { TVPairingView() }
            else if store.device.lockState.isLocked { TVLockedView() }
            else { TVUnlockedView() }
        }
        .animation(reduceMotion ? .easeOut(duration: 0.25) : .smooth(duration: 0.8), value: store.device.lockState)
        .onChange(of: store.device.lockState) { oldValue, newValue in
            guard oldValue.isLocked, !newValue.isLocked else { return }
            showingUnlockTransition = true
            Task {
                try? await Task.sleep(for: .seconds(reduceMotion ? 0.6 : 1.8))
                withAnimation(.easeOut(duration: 0.45)) { showingUnlockTransition = false }
            }
        }
        .overlay(alignment: .topTrailing) {
            if updates.status == .updateAvailable, let version = updates.manifest?.latestVersion {
                Label("Administrator update required · \(version)", systemImage: "arrow.down.circle.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 22).padding(.vertical, 13)
                    .background(.black.opacity(0.72), in: Capsule())
                    .padding(.trailing, 64).padding(.top, 54)
            }
        }
        .overlay(alignment: .bottom) {
            Text("Device ID · \(store.device.id.uuidString)")
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.34))
                .lineLimit(1)
                .padding(.bottom, 16)
        }
        .overlay(alignment: .bottomTrailing) {
            if store.isPaired {
                TVDisconnectButton()
                    .padding(.trailing, 64)
                    .padding(.bottom, 44)
            }
        }
    }
}

private struct TVUnlockTransitionView: View {
    @EnvironmentObject private var store: DeviceStateStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var revealed = false

    var body: some View {
        ZStack {
            AnimatedGradientBackground(preset: store.gradientPreset, vibrantOnBlack: true)
            VStack(spacing: 30) {
                Image(systemName: "lock.open.fill")
                    .font(.system(size: 88, weight: .semibold))
                    .frame(width: 180, height: 180)
                    .background(.ultraThinMaterial, in: Circle())
                Text("DEVICE UNLOCKED").font(.system(size: 66, weight: .bold)).expandedFont().tracking(1)
            }
            .scaleEffect(revealed || reduceMotion ? 1 : 0.82)
            .opacity(revealed ? 1 : 0).foregroundStyle(.white)
        }
        .overlay(alignment: .top) { TVBrandHeader() }
        .onAppear { withAnimation(.spring(response: 0.65, dampingFraction: 0.82)) { revealed = true } }
    }
}
