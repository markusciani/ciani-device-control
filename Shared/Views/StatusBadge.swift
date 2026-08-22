import SwiftUI

struct StatusBadge: View {
    let status: ConnectionStatus
    var body: some View {
        Label(status.label, systemImage: status.symbol)
            .font(.caption.weight(.semibold)).padding(.horizontal, 10).padding(.vertical, 6)
            .background(.thinMaterial, in: Capsule())
            .accessibilityLabel("Connection status: \(status.label)")
    }
}
