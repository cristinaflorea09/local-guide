import SwiftUI
import AuthenticationServices

struct LoginView: View {
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

                    AppleSignInButtonView(onCompletion: { result in
                        Task { await handleApple(result) }
                    })

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
        do { try await AuthService.shared.login(email: email, password: password) }
        catch { errorMessage = error.localizedDescription }
        isLoading = false
        print("✅ FirebaseAuth login success")

    }

    private func handleApple(_ result: Result<ASAuthorization, Error>) async {
        errorMessage = nil
        switch result {
        case .success(let auth):
            do { try await AuthService.shared.signInWithApple(authorization: auth) }
            catch { errorMessage = error.localizedDescription }
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }
}
