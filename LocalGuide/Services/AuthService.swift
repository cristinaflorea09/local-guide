import Foundation
import FirebaseAuth
import AuthenticationServices

final class AuthService {
    static let shared = AuthService()

    private init() {}

    func register(email: String, password: String, role: UserRole) async throws -> String {
        let result = try await Auth.auth().createUser(withEmail: email, password: password)
        let uid = result.user.uid

        let user = AppUser(
            id: uid,
            email: email,
            role: role,
            createdAt: Date(),
            disabled: false,
            guideProfileCreated: role == .guide ? false : nil,
            guideApproved: role == .guide ? false : nil
        )
        try await FirestoreService.shared.createUser(user)
        return uid
    }

    func login(email: String, password: String) async throws {
        _ = try await Auth.auth().signIn(withEmail: email, password: password)
    }

    func signOut() throws {
        try Auth.auth().signOut()
    }

    // In your AuthService class:
    private var currentNonce: String?

    // MARK: - Sign in with Apple (Firebase Auth)
    func signInWithApple(authorization: ASAuthorization) async throws {
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            throw NSError(domain: "AppleSignIn", code: 0,
                          userInfo: [NSLocalizedDescriptionKey: "Invalid Apple credential"])
        }

        guard let appleToken = appleIDCredential.identityToken,
              let tokenString = String(data: appleToken, encoding: .utf8) else {
            throw NSError(domain: "AppleSignIn", code: 0,
                          userInfo: [NSLocalizedDescriptionKey: "Unable to fetch identity token"])
        }

        guard let nonce = currentNonce else {
            throw NSError(domain: "AppleSignIn", code: 0,
                          userInfo: [NSLocalizedDescriptionKey: "Missing nonce. Start Apple sign-in again."])
        }

        let credential = OAuthProvider.appleCredential(
            withIDToken: tokenString,
            rawNonce: nonce,
            fullName: appleIDCredential.fullName
        )

        let result = try await Auth.auth().signIn(with: credential)
        let uid = result.user.uid

        // Ensure user doc exists (default role: user)
        do {
            _ = try await FirestoreService.shared.getUser(uid: uid)
        } catch {
            let email = appleIDCredential.email ?? result.user.email
            let user = AppUser(id: uid, email: email, role: .user, createdAt: Date(), disabled: false)
            try await FirestoreService.shared.createUser(user)
        }

        // Optional: clear nonce after use
        currentNonce = nil
    }
}
