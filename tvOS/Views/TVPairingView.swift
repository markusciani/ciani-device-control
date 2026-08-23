import SwiftUI

struct TVPairingView: View {
    @EnvironmentObject private var store: DeviceStateStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var scanning = false
    @State private var appeared = false

    var body: some View {
        ZStack {
            AnimatedGradientBackground(preset: store.gradientPreset, vibrantOnBlack: true)
            VStack(spacing: 24) {
                Image(systemName: "lock.shield.fill").font(.system(size: 72)).frame(width: 150, height: 150)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 42))
                Text("Set Up This Apple TV").font(.title2.weight(.semibold)).expandedFont()
                Text("Pair with a Ciani Device Control administrator.").foregroundStyle(.white.opacity(0.76))
                VStack(spacing: 10) {
                    Text("PAIRING CODE").font(.headline).compressedFont().tracking(3).foregroundStyle(.white.opacity(0.72))
                    Text(store.pairingCode).font(.system(size: 68, weight: .bold, design: .rounded)).expandedFont().monospacedDigit().tracking(8)
                }.padding(.horizontal, 60).padding(.vertical, 28).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 30))
                Label("Waiting for controller…", systemImage: "antenna.radiowaves.left.and.right")
                    .compressedFont().foregroundStyle(.white.opacity(0.7)).symbolEffect(.variableColor.iterative, options: .repeating, value: scanning)
            }.padding(.horizontal, 80).padding(.vertical, 48)
                .background(.black.opacity(0.38), in: RoundedRectangle(cornerRadius: 44))
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
