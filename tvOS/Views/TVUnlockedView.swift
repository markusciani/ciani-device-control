import SwiftUI

struct TVUnlockedView: View {
    @EnvironmentObject private var store: DeviceStateStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    var body: some View {
        ZStack {
            AnimatedGradientBackground(preset: store.gradientPreset, vibrantOnBlack: true)
            VStack(spacing: 34) {
                Image(systemName: "appletv.fill")
                    .font(.system(size: 74, weight: .medium))
                    .symbolRenderingMode(.hierarchical)
                Text(store.device.name)
                    .font(.system(size: 54, weight: .semibold))
                    .lineLimit(1).minimumScaleFactor(0.7)
                HStack(spacing: 56) {
                    detail("Network", "Connected", "wifi")
                    detail("Controller", "Paired", "iphone.and.arrow.forward")
                    detail("Version", AppVersion.display, "shippingbox")
                }
            }.padding(.horizontal, 100).padding(.vertical, 58)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 38, style: .continuous))
                .foregroundStyle(.white).opacity(appeared ? 1 : 0).scaleEffect(appeared || reduceMotion ? 1 : 0.94)
        }
        .overlay(alignment: .top) { TVBrandHeader() }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) { appeared = true }
        }
    }

    private func detail(_ title: String, _ value: String, _ symbol: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: symbol).font(.title2)
            Text(value).font(.headline)
            Text(title).font(.caption).foregroundStyle(.white.opacity(0.58))
        }.frame(minWidth: 180)
    }
}
