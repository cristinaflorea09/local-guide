import SwiftUI
import AuthenticationServices
import UIKit

struct LoginView: View {
    @EnvironmentObject var router: AuthRouter
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var isSocialLoading = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("auth_welcome_back")
                        .font(.title.bold())
                        .foregroundStyle(.white)

                    LuxuryTextField(title: "Email", text: $email, keyboard: .emailAddress, identifier: "login_email")
                    LuxuryTextField(title: "Password", text: $password, secure: true, identifier: "login_password")

                    Button { Task { await login() } } label: {
                        if isLoading { ProgressView() } else { Text("auth_login") }
                    }
                    .buttonStyle(LuxuryPrimaryButtonStyle())
                    .disabled(isLoading || isSocialLoading || email.isEmpty || password.isEmpty)
                    .accessibilityIdentifier("login_submit")

                    Text("Or")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.6))
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 6)

                    AppleSignInButtonView { result, nonce in
                        Task { await handleApple(result, nonce: nonce) }
                    }

                    GoogleSignInButtonView(isLoading: isSocialLoading) {
                        Task { await handleGoogle() }
                    }

                    if let errorMessage { Text(errorMessage).foregroundStyle(.red) }

                    Spacer(minLength: 10)
                }
                .padding(18)
            }
            LanguageSwitcherOverlay()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(.trailing, 12)
                .padding(.top, 10)
        }
        .navigationTitle("Login")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func login() async {
        isLoading = true
        errorMessage = nil
        do {
            try await AuthService.shared.login(email: email, password: password)
            // Ensure we have fresh email verification state.
            try? await AuthService.shared.reloadCurrentUser()
            // RootView handles email verification gating.
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func handleApple(_ result: Result<ASAuthorization, Error>, nonce: String?) async {
        errorMessage = nil
        switch result {
        case .success(let auth):
            guard let nonce else {
                errorMessage = "Apple Sign-In failed. Please try again."
                return
            }
            do { try await AuthService.shared.signInWithApple(authorization: auth, rawNonce: nonce) }
            catch { errorMessage = error.localizedDescription }
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }

    private func handleGoogle() async {
        errorMessage = nil
        guard let presenting = topViewController() else {
            errorMessage = "Unable to start Google Sign-In. Please try again."
            return
        }
        isSocialLoading = true
        defer { isSocialLoading = false }
        do {
            try await AuthService.shared.signInWithGoogle(presenting: presenting)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func topViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let keyWindow = scenes.flatMap { $0.windows }.first { $0.isKeyWindow }
        var top = keyWindow?.rootViewController
        while let presented = top?.presentedViewController {
            top = presented
        }
        return top
    }
}
