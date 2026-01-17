import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @EnvironmentObject var router: AuthRouter
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Welcome back")
                        .font(.title.bold())
                        .foregroundStyle(.white)

                    LuxuryTextField(title: "Email", text: $email, keyboard: .emailAddress)
                    LuxuryTextField(title: "Password", text: $password, secure: true)

                    Button { Task { await login() } } label: {
                        if isLoading { ProgressView() } else { Text("Login") }
                    }
                    .buttonStyle(LuxuryPrimaryButtonStyle())
                    .disabled(isLoading || email.isEmpty || password.isEmpty)

                    Text("Or")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.6))
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 6)

                    AppleSignInButtonView { result, nonce in
                        Task { await handleApple(result, nonce: nonce) }
                    }

                    if let errorMessage { Text(errorMessage).foregroundStyle(.red) }

                    Spacer(minLength: 10)
                }
                .padding(18)
            }
        }
        .navigationTitle("Login")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func login() async {
        isLoading = true
        errorMessage = nil
        do {
            try await AuthService.shared.login(email: email, password: password)
            // RootView listens to auth state; once it switches to Home, AuthFlow disappears.
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func handleApple(_ result: Result<ASAuthorization, Error>, nonce: String?) async {
        switch result {
        case .success(let authorization):
            guard let nonce else {
                // nonce missing = request didn’t run properly
                return
            }
            do {
                try await AuthService.shared.signInWithApple(authorization: authorization, rawNonce: nonce)
            } catch {
                // show error
            }

        case .failure(let error):
            // show error
            print(error.localizedDescription)
        }
    }

}
