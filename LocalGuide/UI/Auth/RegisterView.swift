import SwiftUI

struct RegisterView: View {
    let role: UserRole

    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(role == .guide ? "Create Guide Account" : "Create Account")
                        .font(.title.bold())
                        .foregroundStyle(.white)

                    LuxuryTextField(title: "Email", text: $email, keyboard: .emailAddress)
                    LuxuryTextField(title: "Password (min 6)", text: $password, secure: true)

                    if let errorMessage { Text(errorMessage).foregroundStyle(.red) }

                    Button { Task { await register() } } label: {
                        if isLoading { ProgressView() } else { Text("Create account") }
                    }
                    .buttonStyle(LuxuryPrimaryButtonStyle())
                    .disabled(isLoading || email.isEmpty || password.count < 6)

                    if role == .guide {
                        Text("Guides are reviewed before going live.")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.6))
                    }

                    Spacer(minLength: 10)
                }
                .padding(18)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    private func register() async {
        isLoading = true
        errorMessage = nil
        do { _ = try await AuthService.shared.register(email: email, password: password, role: role) }
        catch { errorMessage = error.localizedDescription }
        isLoading = false
    }
}
