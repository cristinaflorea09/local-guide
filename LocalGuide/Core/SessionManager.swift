import Foundation
import FirebaseAuth

@MainActor
final class SessionManager: ObservableObject {
    @Published var firebaseUser: User? = nil
    @Published var currentUser: AppUser? = nil
    @Published var isLoading: Bool = true

    private var handle: AuthStateDidChangeListenerHandle?

    func startListening() {
        isLoading = true
        handle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self else { return }
            self.firebaseUser = user

            if let user {
                Task {
                    do {
                        let appUser = try await FirestoreService.shared.getUser(uid: user.uid)
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
                self.isLoading = false
            }
        }
    }

    func signOut() {
        do { try AuthService.shared.signOut() } catch { }
        firebaseUser = nil
        currentUser = nil
    }
}
