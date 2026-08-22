#if os(iOS)
import SwiftUI
import LocalAuthentication

@MainActor
final class AuthenticationModel: ObservableObject {
    @Published var enteredPIN = ""
    @Published var isAuthenticated = false
    @Published var errorPulse = false
    @Published private(set) var isFaceIDEnabled: Bool
    @Published private(set) var canUseFaceID = false
    @Published private(set) var isAuthenticatingWithFaceID = false
    @Published var authenticationMessage: String?
    @Published private(set) var biometryType: LABiometryType = .none

    private let defaultPIN = "2010"
    private var storedPIN: String { SecureStore.get("master-pin") ?? defaultPIN }
    var biometricName: String { biometryType == .touchID ? "Touch ID" : "Face ID" }
    var biometricSymbol: String { biometryType == .touchID ? "touchid" : "faceid" }

    init() {
        isFaceIDEnabled = UserDefaults.standard.bool(forKey: "face-id-enabled")
        if let existingPIN = SecureStore.get("master-pin") {
            SecureStore.set(existingPIN, for: "master-pin")
        }
        refreshFaceIDAvailability()
    }

    func enter(_ digit: Int) {
        guard enteredPIN.count < 4 else { return }
        enteredPIN.append(String(digit))
        if enteredPIN.count == 4 { validate() }
    }

    func delete() { if !enteredPIN.isEmpty { enteredPIN.removeLast() } }
    func signOut() { enteredPIN = ""; isAuthenticated = false }

    func changePIN(to value: String) -> Bool {
        guard value.count == 4, value.allSatisfy(\.isNumber) else { return false }
        SecureStore.set(value, for: "master-pin")
        return true
    }

    func refreshFaceIDAvailability() {
        let context = LAContext()
        var error: NSError?
        let available = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
        biometryType = context.biometryType
        canUseFaceID = available && (biometryType == .faceID || biometryType == .touchID)
        if !canUseFaceID, isFaceIDEnabled {
            isFaceIDEnabled = false
            UserDefaults.standard.set(false, forKey: "face-id-enabled")
        }
    }

    func setFaceIDEnabled(_ enabled: Bool) {
        if !enabled {
            isFaceIDEnabled = false
            UserDefaults.standard.set(false, forKey: "face-id-enabled")
            return
        }
        authenticateWithFaceID(reason: "Enable \(biometricName) for Ciani Device Control") { [weak self] success in
            guard let self, success else { return }
            self.isFaceIDEnabled = true
            UserDefaults.standard.set(true, forKey: "face-id-enabled")
        }
    }

    func authenticateWithFaceIDIfEnabled() {
        guard isFaceIDEnabled, !isAuthenticated else { return }
        authenticateWithFaceID(reason: "Unlock Ciani Device Control")
    }

    func authenticateWithFaceID(reason: String = "Unlock Ciani Device Control", completion: ((Bool) -> Void)? = nil) {
        guard canUseFaceID, !isAuthenticatingWithFaceID else {
            authenticationMessage = "Biometric authentication is not available on this device."
            completion?(false)
            return
        }
        let context = LAContext()
        context.localizedCancelTitle = "Enter PIN"
        isAuthenticatingWithFaceID = true
        context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { [weak self] success, error in
            Task { @MainActor in
                guard let self else { return }
                self.isAuthenticatingWithFaceID = false
                if success {
                    self.authenticationMessage = nil
                    withAnimation(.easeInOut(duration: 0.4)) { self.isAuthenticated = true }
                } else if let code = (error as? LAError)?.code, code != .userCancel, code != .appCancel {
                    self.authenticationMessage = "\(self.biometricName) could not verify your identity. Enter your administrator PIN."
                }
                completion?(success)
            }
        }
    }

    private func validate() {
        if enteredPIN == storedPIN {
            withAnimation(.easeInOut(duration: 0.45)) { isAuthenticated = true }
        } else {
            errorPulse.toggle()
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            Task { try? await Task.sleep(for: .milliseconds(350)); enteredPIN = "" }
        }
    }
}
#endif
