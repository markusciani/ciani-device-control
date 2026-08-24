import SwiftUI

struct TVPairingView: View {
    @EnvironmentObject private var store: DeviceStateStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var scanning = false
    @State private var appeared = false

    var body: some View {
        ZStack {
            AnimatedGradientBackground(preset: store.gradientPreset, vibrantOnBlack: true)
            HStack(spacing: 72) {
                VStack(alignment: .leading, spacing: 20) {
                    Image(systemName: "lock.shield.fill").font(.system(size: 68))
                    Text("Pair this Apple TV").font(.system(size: 48, weight: .semibold))
                    Text("On the administrator app, choose Add Device and enter this code.")
                        .font(.title3).foregroundStyle(.white.opacity(0.66)).frame(maxWidth: 520, alignment: .leading)
                    Label("Waiting for a controller", systemImage: "antenna.radiowaves.left.and.right")
                        .foregroundStyle(.white.opacity(0.72)).symbolEffect(.variableColor.iterative, options: .repeating, value: scanning)
                }
                VStack(spacing: 12) {
                    Text("PAIRING CODE").font(.headline).tracking(3).foregroundStyle(.white.opacity(0.58))
                    Text(store.pairingCode)
                        .font(.system(size: 82, weight: .bold, design: .rounded))
                        .monospacedDigit().tracking(10)
                }
                .padding(.horizontal, 58).padding(.vertical, 46)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 34, style: .continuous))
            }.padding(.horizontal, 92).padding(.vertical, 58)
                .foregroundStyle(.white).opacity(appeared ? 1 : 0).offset(y: appeared || reduceMotion ? 0 : 24)
        }
        .overlay(alignment: .top) { TVBrandHeader() }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) { appeared = true }
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: false)) { scanning = true }
        }
    }
}
