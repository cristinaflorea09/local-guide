import Foundation
import FirebaseAuth
import AuthenticationServices
import FirebaseCore
import GoogleSignIn

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

    func deleteCurrentUser() async throws {
        guard let user = Auth.auth().currentUser else { return }
        try await user.delete()
    }

    func reauthenticateWithApple(authorization: ASAuthorization, rawNonce: String) async throws {
        guard let user = Auth.auth().currentUser else { return }
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
        try await user.reauthenticate(with: credential)
    }

    func reauthenticateWithGoogle(presenting: UIViewController) async throws {
        guard let user = Auth.auth().currentUser else { return }
        guard let clientID = googleClientID() else {
            throw NSError(
                domain: "AuthService",
                code: 0,
                userInfo: [NSLocalizedDescriptionKey: "Missing Google client ID. Re-download GoogleService-Info.plist from Firebase (must include CLIENT_ID) and add the REVERSED_CLIENT_ID URL scheme."]
            )
        }

        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config

        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presenting)
        let signedInUser = result.user

        guard let idToken = signedInUser.idToken?.tokenString else {
            throw NSError(domain: "AuthService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Unable to fetch Google ID token"])
        }

        let accessToken = signedInUser.accessToken.tokenString
        let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: accessToken)
        try await user.reauthenticate(with: credential)
    }

    func reauthenticateWithPassword(email: String, password: String) async throws {
        guard let user = Auth.auth().currentUser else { return }
        let credential = EmailAuthProvider.credential(withEmail: email, password: password)
        try await user.reauthenticate(with: credential)
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
                acceptedTermsVersion: 1,
                acceptedTermsAt: Date(),
                photoURL: nil,
                createdAt: Date()
            )
            try await FirestoreService.shared.createUser(user)
        }
    }

    // Google Sign In
    func signInWithGoogle(presenting: UIViewController) async throws {
        guard let clientID = googleClientID() else {
            throw NSError(
                domain: "AuthService",
                code: 0,
                userInfo: [NSLocalizedDescriptionKey: "Missing Google client ID. Re-download GoogleService-Info.plist from Firebase (must include CLIENT_ID) and add the REVERSED_CLIENT_ID URL scheme."]
            )
        }

        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config

        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presenting)
        let user = result.user

        guard let idToken = user.idToken?.tokenString else {
            throw NSError(domain: "AuthService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Unable to fetch Google ID token"])
        }

        let accessToken = user.accessToken.tokenString
        let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: accessToken)

        let authResult = try await Auth.auth().signIn(with: credential)
        let uid = authResult.user.uid

        // Ensure user doc exists (default traveler)
        _ = try await FirestoreService.shared.getOrCreateUser(
            uid: uid,
            email: authResult.user.email,
            roleHint: .traveler
        )
    }

    private func googleClientID() -> String? {
        if let id = FirebaseApp.app()?.options.clientID, !id.isEmpty {
            return id
        }
        if let id = Bundle.main.object(forInfoDictionaryKey: "GIDClientID") as? String, !id.isEmpty {
            return id
        }
        guard let url = Bundle.main.url(forResource: "GoogleService-Info", withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let id = plist["CLIENT_ID"] as? String,
              !id.isEmpty else {
            return nil
        }
        return id
    }
}
