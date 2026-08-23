import SwiftUI

struct TVUnlockedView: View {
    @EnvironmentObject private var store: DeviceStateStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    var body: some View {
        ZStack {
            AnimatedGradientBackground(preset: store.gradientPreset, vibrantOnBlack: true)
            VStack(spacing: 22) {
                Image(systemName: "appletv.fill").font(.system(size: 64)).frame(width: 142, height: 142)
                    .background(.ultraThinMaterial, in: Circle())
                Label("Available", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 42, weight: .bold))
                    .expandedFont()
                Text("Ready for administrator commands")
                    .font(.title2).compressedFont().foregroundStyle(.white.opacity(0.72))
                Text("Press Menu to exit")
                    .font(.title3).compressedFont().foregroundStyle(.white.opacity(0.58))
            }.padding(.horizontal, 90).padding(.vertical, 60)
                .background(.black.opacity(0.38), in: RoundedRectangle(cornerRadius: 44))
                .foregroundStyle(.white).opacity(appeared ? 1 : 0).scaleEffect(appeared || reduceMotion ? 1 : 0.94)
        }
        .overlay(alignment: .top) { TVBrandHeader() }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) { appeared = true }
        }
    }
}
