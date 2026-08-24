import SwiftUI

struct TVUnlockedView: View {
    @EnvironmentObject private var store: DeviceStateStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    var body: some View {
        ZStack {
            AnimatedGradientBackground(preset: store.gradientPreset, vibrantOnBlack: true)
            VStack(alignment: .leading, spacing: 24) {
                Image(systemName: "appletv.fill")
                    .font(.system(size: 68, weight: .medium))
                    .symbolRenderingMode(.hierarchical)
                Text(store.device.name)
                    .font(.system(size: 64, weight: .semibold))
                    .lineLimit(1).minimumScaleFactor(0.7)
                Label("Connected to controller", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 26, weight: .medium))
                    .foregroundStyle(.white.opacity(0.72))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .padding(.leading, 96)
            .padding(.top, 118)
            .foregroundStyle(.white)
            .opacity(appeared ? 1 : 0)
            .offset(x: appeared || reduceMotion ? 0 : -36)
        }
        .overlay(alignment: .topLeading) { TVBrandHeader() }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) { appeared = true }
        }
    }

}
