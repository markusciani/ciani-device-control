import SwiftUI

struct TVDisconnectButton: View {
    @EnvironmentObject private var connection: ConnectionManager
    @State private var showingConfirmation = false
    @State private var pin = ""
    @State private var errorMessage: String?
    private let keypad = [1, 2, 3, 4, 5, 6, 7, 8, 9, -2, 0, -1]
    private let keypadColumns = Array(repeating: GridItem(.fixed(138), spacing: 18), count: 3)

    var body: some View {
        Button {
            pin = ""
            errorMessage = nil
            showingConfirmation = true
        } label: {
            Image(systemName: "iphone.slash")
                .font(.system(size: 25, weight: .semibold))
                .frame(width: 52, height: 52)
                .accessibilityLabel("Disconnect Controller")
        }
        .buttonStyle(.borderedProminent)
        .tint(.white.opacity(0.8))
        .fullScreenCover(isPresented: $showingConfirmation) {
            ZStack {
                Color.black.opacity(0.9).ignoresSafeArea()
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
                    LazyVGrid(columns: keypadColumns, spacing: 18) {
                        ForEach(keypad, id: \.self) { key in
                            if key == -2 {
                                Color.clear.frame(width: 138, height: 68)
                            } else if key == -1 {
                                Button {
                                    if !pin.isEmpty { pin.removeLast() }
                                    errorMessage = nil
                                } label: {
                                    Image(systemName: "delete.left.fill")
                                        .font(.system(size: 30, weight: .semibold))
                                        .frame(width: 138, height: 68)
                                }
                                .disabled(pin.isEmpty)
                            } else {
                                Button("\(key)") {
                                    guard pin.count < 4 else { return }
                                    pin.append(String(key))
                                    errorMessage = nil
                                }
                                .font(.system(size: 34, weight: .bold, design: .rounded))
                                .frame(width: 138, height: 68)
                            }
                        }
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
                .frame(width: 1640, height: 930)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 54, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 54, style: .continuous)
                        .stroke(.white.opacity(0.14), lineWidth: 2)
                }
            }
            .onExitCommand { showingConfirmation = false }
        }
    }
}
