import SwiftUI

struct TVUnlockedView: View {
    @EnvironmentObject private var store: DeviceStateStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    var body: some View {
        ZStack {
            AnimatedGradientBackground(preset: store.gradientPreset, vibrantOnBlack: true)
            VStack(spacing: 24) {
                Image(systemName: "appletv.fill").font(.system(size: 68)).frame(width: 150, height: 150)
                    .background(.ultraThinMaterial, in: Circle())
                Text(store.device.name).font(.system(size: 54, weight: .bold)).expandedFont()
                VStack(spacing: 10) {
                    Label("Available", systemImage: "checkmark.circle.fill")
                    Text("Device ID  \(store.device.id.uuidString)")
                    Text("Version \(AppVersion.display)")
                }
                .font(.title3).compressedFont().foregroundStyle(.white.opacity(0.78))
                Text("Press Menu to exit.").font(.title2).compressedFont().foregroundStyle(.white.opacity(0.68))
                TVDisconnectButton()
            }.padding(.horizontal, 90).padding(.vertical, 60)
                .background(.black.opacity(0.38), in: RoundedRectangle(cornerRadius: 44))
                .foregroundStyle(.white).opacity(appeared ? 1 : 0).scaleEffect(appeared || reduceMotion ? 1 : 0.94)
        }
        .overlay(alignment: .topLeading) { TVBrandHeader() }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) { appeared = true }
        }
    }
}
