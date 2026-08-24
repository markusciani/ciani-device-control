import SwiftUI

struct TVLockedView: View {
    @EnvironmentObject private var store: DeviceStateStore
    @EnvironmentObject private var connection: ConnectionManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var recentlyUnlocked = false
    @State private var appeared = false

    var body: some View {
        ZStack {
            AnimatedGradientBackground(preset: store.gradientPreset, vibrantOnBlack: true)
            VStack(alignment: .leading, spacing: 18) {
                Image(systemName: "lock.fill").font(.system(size: 62, weight: .semibold))
                    .contentTransition(.symbolEffect(.replace)).frame(width: 132, height: 132)
                    .background(.ultraThinMaterial, in: Circle())
                Text("DEVICE LOCKED").font(.system(size: 56, weight: .bold)).expandedFont().tracking(1)
                if let message = store.device.customMessage {
                    Text(message).font(.system(size: 30, weight: .medium)).multilineTextAlignment(.leading)
                        .foregroundStyle(.white.opacity(0.82)).lineLimit(3).minimumScaleFactor(0.75).padding(.top, 4)
                }
                if let unlockAt = store.device.lockState.unlockAt {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        let remaining = CountdownLogic.remaining(until: unlockAt, now: context.date)
                        VStack(alignment: .leading, spacing: 0) {
                            Text(remaining.formatted).font(.system(size: 104, weight: .bold, design: .rounded))
                                .expandedFont().monospacedDigit().contentTransition(.numericText())
                            Text("REMAINING").font(.headline.bold()).compressedFont().tracking(4).foregroundStyle(.white.opacity(0.72))
                        }.onChange(of: remaining.seconds) { _, seconds in if seconds == 0 { unlockWithTransition() } }
                    }
                } else {
                    Text("Waiting for administrator approval.").font(.title2).padding(.top, 18)
                }
            }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .padding(.leading, 96).padding(.top, 124).padding(.trailing, 520)
                .foregroundStyle(.white)
                .opacity(appeared ? 1 : 0)
                .offset(x: appeared || reduceMotion ? 0 : -36)
        }
        .overlay(alignment: .topLeading) { TVBrandHeader() }
        .onExitCommand { }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) { appeared = true }
        }
    }

    private func unlockWithTransition() {
        guard !recentlyUnlocked else { return }
        recentlyUnlocked = true
        if reduceMotion { store.unlock() }
        else { withAnimation(.easeInOut(duration: 0.7)) { store.unlock() } }
        connection.requestSystemUnlock()
    }
}
