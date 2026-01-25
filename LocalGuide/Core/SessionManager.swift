import Foundation
import FirebaseAuth

@MainActor
final class SessionManager: ObservableObject {
    @Published var firebaseUser: User? = nil
    @Published var currentUser: AppUser? = nil
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil

    /// Best-effort role determined from Firebase custom claims at sign-in time.
    /// This is used for routing decisions before `currentUser` is loaded from Firestore.
    @Published var authRoleHint: UserRole = .traveler

    /// When true, RootView will open the auth flow directly on Login (used after email verification sign-out).
    @Published var startAuthAtLoginNext: Bool = false

    var isEmailVerified: Bool { firebaseUser?.isEmailVerified ?? false }

    private var handle: AuthStateDidChangeListenerHandle?

    func startListening() {
        isLoading = true
        handle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self else { return }
            self.firebaseUser = user

            if let user {
                Task {
                    do {
                        // Determine role from custom claims if present (used for admin accounts).
                        var roleHint: UserRole = .traveler
                        do {
                            let token = try await user.getIDTokenResult()
                            if let role = token.claims["role"] as? String,
                               let parsed = UserRole(rawValue: role) {
                                roleHint = parsed
                            } else if let isAdmin = token.claims["admin"] as? Bool, isAdmin {
                                roleHint = .admin
                            }
                        } catch {
                            // Ignore token/claims failures; fall back to traveler.
                        }

                        // Publish the claim-derived role early so RootView can route correctly.
                        self.authRoleHint = roleHint

                        let appUser = try await FirestoreService.shared.getOrCreateUser(
                            uid: user.uid,
                            email: user.email,
                            roleHint: roleHint
                        )
                        if appUser.disabled {
                            try? AuthService.shared.signOut()
                            self.currentUser = nil
                            self.isLoading = false
                            return
                        }
                        self.currentUser = appUser
                        self.isLoading = false
                    } catch {
                        self.currentUser = nil
                        self.isLoading = false
                    }
                }
            } else {
                self.currentUser = nil
                self.authRoleHint = .traveler
                self.isLoading = false
            }
        }
    }

    func signOut() {
        do { try AuthService.shared.signOut() } catch { }
        firebaseUser = nil
        currentUser = nil
    }

    /// Signs out and asks RootView to show the Login screen next.
    func signOutAndShowLogin() {
        startAuthAtLoginNext = true
        signOut()
    }

    @MainActor
    func refreshCurrentUserIfAvailable() async {
        guard let uid = firebaseUser?.uid else { return }
        do {
            // User docs are keyed by lowercased email after migration.
            currentUser = try await FirestoreService.shared.getUserByAuth(uid: uid, email: firebaseUser?.email)
        } catch { }
    }
}
