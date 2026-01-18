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
        subscriptionPlan: SubscriptionPlan,
        acceptedTermsVersion: Int
    ) async throws -> String {
        let result = try await Auth.auth().createUser(withEmail: email, password: password)
        let uid = result.user.uid

        // Send email verification
        try await result.user.sendEmailVerification()

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
            guideProfileCreated: role == .guide ? false : nil,
            guideApproved: role == .guide ? false : nil,
            hostApproved: role == .host ? false : nil,
            sellerTier: nil,
            disabled: false,
            acceptedTermsVersion: acceptedTermsVersion,
            acceptedTermsAt: Date(),
            photoURL: nil,
            createdAt: Date()
        )

        try await FirestoreService.shared.createUser(user)
        return uid
    }

    func login(email: String, password: String) async throws {
        _ = try await Auth.auth().signIn(withEmail: email, password: password)
    }

    func reloadCurrentUser() async throws {
        guard let u = Auth.auth().currentUser else { return }
        try await u.reload()
    }

    func resendEmailVerification() async throws {
        guard let u = Auth.auth().currentUser else { return }
        try await u.sendEmailVerification()
    }

    func signOut() throws {
        try Auth.auth().signOut()
    }

    // Apple Sign In
    func signInWithApple(authorization: ASAuthorization, rawNonce: String) async throws {
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            throw NSError(domain: "AuthService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid Apple credential"])
        }

        guard let identityToken = appleIDCredential.identityToken,
              let idTokenString = String(data: identityToken, encoding: .utf8) else {
            throw NSError(domain: "AuthService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Unable to fetch identity token"])
        }

        let credential = OAuthProvider.appleCredential(
            withIDToken: idTokenString,
            rawNonce: rawNonce,
            fullName: appleIDCredential.fullName
        )

        let result = try await Auth.auth().signIn(with: credential)
        let uid = result.user.uid

        // Ensure user doc exists (default traveler)
        do {
            _ = try await FirestoreService.shared.getUser(uid: uid)
        } catch {
            let email = appleIDCredential.email ?? result.user.email
            let fullName = [appleIDCredential.fullName?.givenName, appleIDCredential.fullName?.familyName]
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
                guideProfileCreated: nil,
                guideApproved: nil,
                sellerTier: nil,
                disabled: false,
                acceptedTermsVersion: nil,
                acceptedTermsAt: nil,
                photoURL: nil,
                createdAt: Date()
            )
            try await FirestoreService.shared.createUser(user)
        }
    }
}
