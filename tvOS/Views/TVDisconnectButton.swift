import SwiftUI

struct TVDisconnectButton: View {
    @EnvironmentObject private var connection: ConnectionManager
    @State private var showingConfirmation = false
    @State private var pin = ""
    @State private var errorMessage: String?

    var body: some View {
        Button {
            pin = ""
            errorMessage = nil
            showingConfirmation = true
        } label: {
            Label("Disconnect Controller", systemImage: "iphone.slash")
                .font(.headline)
        }
        .buttonStyle(.bordered)
        .tint(.white.opacity(0.8))
        .sheet(isPresented: $showingConfirmation) {
            NavigationStack {
                VStack(spacing: 30) {
                    Image(systemName: "lock.shield.fill").font(.system(size: 72))
                    Text("Disconnect This Apple TV?")
                        .font(.system(size: 46, weight: .bold))
                        .expandedFont()
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Text("Enter the four-digit administrator PIN. This Apple TV will leave every connected controller and return to its pairing screen.")
                        .font(.system(size: 28, weight: .medium))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: 1200)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 18) {
                        ForEach(0..<4, id: \.self) { index in
                            Circle()
                                .fill(index < pin.count ? Color.primary : Color.clear)
                                .stroke(.primary.opacity(0.7), lineWidth: 3)
                                .frame(width: 20, height: 20)
                        }
                    }
                    HStack(spacing: 12) {
                        ForEach(0...9, id: \.self) { digit in
                            Button("\(digit)") {
                                guard pin.count < 4 else { return }
                                pin.append(String(digit))
                                errorMessage = nil
                            }
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .frame(width: 64, height: 56)
                        }
                        Button { if !pin.isEmpty { pin.removeLast() }; errorMessage = nil } label: {
                            Image(systemName: "delete.left.fill")
                                .font(.system(size: 25, weight: .semibold))
                                .frame(width: 72, height: 56)
                        }
                        .disabled(pin.isEmpty)
                    }
                    if let errorMessage {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                    }
                    HStack(spacing: 24) {
                        Button("Cancel") { showingConfirmation = false }
                        Button("Disconnect", role: .destructive) {
                            if connection.disconnectFromController(pin: pin) {
                                showingConfirmation = false
                            } else {
                                pin = ""
                                errorMessage = "That administrator PIN is incorrect."
                            }
                        }
                        .disabled(pin.count != 4 || !pin.allSatisfy(\.isNumber))
                    }
                }
                .padding(.horizontal, 110)
                .padding(.vertical, 60)
                .frame(width: 1480, height: 760)
            }
        }
    }
}
