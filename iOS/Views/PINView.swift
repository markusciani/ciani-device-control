import SwiftUI

struct PINView: View {
    @EnvironmentObject private var auth: AuthenticationModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("animated-background") private var animatedBackground = true
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 20), count: 3)

    var body: some View {
        ZStack {
            AnimatedGradientBackground(animates: animatedBackground)
            VStack(spacing: 26) {
                Spacer()
                Image(systemName: "lock.shield.fill").font(.system(size: 46, weight: .semibold))
                    .frame(width: 92, height: 92).background(.ultraThinMaterial, in: Circle())
                VStack(spacing: 6) {
                    Text("Ciani Device Control").font(.title.bold()).expandedFont()
                    Text("MASTER CONTROL").font(.subheadline.weight(.semibold)).tracking(2).foregroundStyle(.secondary)
                }
                HStack(spacing: 16) {
                    ForEach(0..<4, id: \.self) { index in
                        Circle().fill(index < auth.enteredPIN.count ? Color.primary : Color.clear)
                            .stroke(.primary.opacity(0.75), lineWidth: 2).frame(width: 16, height: 16)
                    }
                }
                .modifier(ShakeEffect(animatableData: auth.errorPulse ? 1 : 0))
                Text("Enter Administrator PIN").foregroundStyle(.secondary)
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(1...9, id: \.self) { key(String($0), digit: $0) }
                    Color.clear.frame(height: 68)
                    key("0", digit: 0)
                    Button { auth.delete() } label: { Image(systemName: "delete.left").frame(maxWidth: .infinity, minHeight: 68) }
                        .buttonStyle(.plain).accessibilityLabel("Delete")
                }.frame(maxWidth: 320)
                if auth.canUseFaceID {
                    Button { auth.authenticateWithFaceID() } label: {
                        Label(auth.isAuthenticatingWithFaceID ? "Verifying…" : "Use \(auth.biometricName)", systemImage: auth.biometricSymbol)
                            .font(.headline).padding(.horizontal, 22).padding(.vertical, 12)
                            .background(.thinMaterial, in: Capsule())
                    }.buttonStyle(.plain).disabled(auth.isAuthenticatingWithFaceID)
                }
                Spacer()
            }.padding(30)
        }
        .task { auth.refreshFaceIDAvailability(); auth.authenticateWithFaceIDIfEnabled() }
        .alert("Authentication", isPresented: Binding(
            get: { auth.authenticationMessage != nil },
            set: { if !$0 { auth.authenticationMessage = nil } }
        )) { Button("OK") { auth.authenticationMessage = nil } }
        message: { Text(auth.authenticationMessage ?? "") }
    }

    private func key(_ title: String, digit: Int) -> some View {
        Button { auth.enter(digit) } label: {
            Text(title).font(.title2.weight(.semibold)).frame(maxWidth: .infinity, minHeight: 68)
                .background(.ultraThinMaterial, in: Circle())
        }.buttonStyle(.plain)
    }
}

private struct ShakeEffect: GeometryEffect {
    var animatableData: CGFloat
    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: 8 * sin(animatableData * .pi * 4), y: 0))
    }
}
