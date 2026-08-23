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
                VStack(spacing: 28) {
                    Image(systemName: "lock.shield.fill").font(.system(size: 64))
                    Text("Disconnect This Apple TV?").font(.title.bold()).expandedFont()
                    Text("Enter the four-digit administrator PIN. This Apple TV will leave every connected controller and return to its pairing screen.")
                        .font(.title3).multilineTextAlignment(.center).foregroundStyle(.secondary).frame(maxWidth: 720)
                    SecureField("Administrator PIN", text: $pin)
                        .keyboardType(.numberPad)
                        .textContentType(.oneTimeCode)
                        .font(.system(size: 34, weight: .semibold, design: .rounded))
                        .multilineTextAlignment(.center)
                        .frame(width: 360)
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
                .padding(70)
            }
        }
    }
}
