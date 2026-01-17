import SwiftUI
import AuthenticationServices

struct AppleSignInButtonView: View {
    var onCompletion: (Result<ASAuthorization, Error>, String) -> Void

    @State private var currentNonce: String?

    var body: some View {
        SignInWithAppleButton(.signIn) { request in
            let nonce = NonceGenerator.randomNonceString()
            currentNonce = nonce

            request.requestedScopes = [.fullName, .email]
            request.nonce = NonceGenerator.sha256(nonce)
        } onCompletion: { result in
            guard let nonce = currentNonce else {
                onCompletion(.failure(NSError(
                    domain: "AppleSignIn",
                    code: 0,
                    userInfo: [NSLocalizedDescriptionKey: "Missing nonce"]
                )), "")
                return
            }
            onCompletion(result, nonce)
        }
        .signInWithAppleButtonStyle(.whiteOutline)
        .frame(height: 50)
    }
}
