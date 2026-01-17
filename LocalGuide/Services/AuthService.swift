import Foundation
import FirebaseAuth
import AuthenticationServices

final class AuthService {
    static let shared = AuthService()
    private init() {}

    // Email/password
    func register(
        email: String,
        password: String,
        role: UserRole,
        fullName: String,
        dateOfBirth: Date?,
        country: String,
        city: String,
        preferredLanguageCode: String,
        subscriptionPlan: SubscriptionPlan
    ) async throws -> String {
        let result = try await Auth.auth().createUser(withEmail: email, password: password)
        let uid = result.user.uid

        let user = AppUser(
            id: uid,
            email: email,
            fullName: fullName,
            dateOfBirth: dateOfBirth,
            country: country,
            city: city,
            preferredLanguageCode: preferredLanguageCode,
            role: role,
            subscriptionPlan: subscriptionPlan,
            disabled: false,
            photoURL: nil,
            createdAt: Date(), guideApproved: false, guideProfileCreated: false
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

    // Apple sign-in: default to traveler role, user can upgrade later in account settings
    func signInWithApple(authorization: ASAuthorization, rawNonce: String) async throws {
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            throw NSError(domain: "AuthService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid Apple credential"])
        }

        guard let identityToken = appleIDCredential.identityToken,
              let idTokenString = String(data: identityToken, encoding: .utf8) else {
            throw NSError(domain: "AuthService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Unable to fetch identity token"])
        }

        let nonce = NonceGenerator.randomNonceString()
        let hashedNonce = NonceGenerator.sha256(nonce)

        let credential = OAuthProvider.appleCredential(
            withIDToken: idTokenString,
            rawNonce: hashedNonce,
            fullName: appleIDCredential.fullName
        )

        let result = try await Auth.auth().signIn(with: credential)
        let uid = result.user.uid

        // Create user document if missing
        do {
            _ = try await FirestoreService.shared.getUser(uid: uid)
        } catch {
            let email = appleIDCredential.email ?? result.user.email
            let fullName = [appleIDCredential.fullName?.givenName,
                            appleIDCredential.fullName?.familyName]
                .compactMap { $0 }
                .joined(separator: " ")

            let user = AppUser(
                id: uid,
                email: email,
                fullName: fullName.isEmpty ? "Traveler" : fullName,
                dateOfBirth: nil,
                country: "",
                city: "",
                preferredLanguageCode: "en",
                role: .traveler,
                subscriptionPlan: .freeAds,
                disabled: false,
                photoURL: nil,
                createdAt: Date(), guideApproved: false, guideProfileCreated: false            )

            try await FirestoreService.shared.createUser(user)
        }
    }
}

