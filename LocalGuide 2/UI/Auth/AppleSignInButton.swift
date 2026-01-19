import SwiftUI
import AuthenticationServices

struct AppleSignInButtonView: View {
    var onCompletion: ((Result<ASAuthorization, Error>, String?) -> Void)?

    @State private var currentNonce: String?

    var body: some View {
        SignInWithAppleButton(.signIn) { request in
            let nonce = NonceGenerator.randomNonceString()
            currentNonce = nonce

            request.requestedScopes = [.fullName, .email]
            request.nonce = NonceGenerator.sha256(nonce)
        } onCompletion: { result in
            onCompletion?(result, currentNonce)
        }
        .signInWithAppleButtonStyle(.black)
        .frame(height: 48)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
