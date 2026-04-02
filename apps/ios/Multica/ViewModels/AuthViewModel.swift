import Foundation

@MainActor
@Observable
final class AuthViewModel {
    var email = ""
    var code = ""
    var isLoading = false
    var error: String?
    var codeSent = false
    var isAuthenticated = false
    var user: User?

    init() {
        // Check for existing token
        if APIClient.shared.token != nil {
            isAuthenticated = true
        }
    }

    func sendCode() async {
        guard !email.isEmpty else {
            error = "Please enter your email"
            return
        }
        isLoading = true
        error = nil
        do {
            try await APIClient.shared.sendCode(email: email)
            codeSent = true
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func verifyCode() async {
        guard !code.isEmpty else {
            error = "Please enter the verification code"
            return
        }
        isLoading = true
        error = nil
        do {
            let response = try await APIClient.shared.verifyCode(email: email, code: code)
            APIClient.shared.token = response.token
            user = response.user
            isAuthenticated = true
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func logout() {
        APIClient.shared.token = nil
        APIClient.shared.workspaceId = nil
        WebSocketClient.shared.disconnect()
        isAuthenticated = false
        user = nil
        email = ""
        code = ""
        codeSent = false
    }
}
