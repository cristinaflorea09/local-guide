func startListening() {
    removeListenerIfPresent()

    addStateDidChangeListener { [weak self] user in
        guard let self else { return }
        print("👂 listener fired; user:", user?.uid ?? "nil")

        Task { @MainActor in
            self.firebaseUser = user
        }

        // Capture a stable user for background work
        guard let stableUser = user else { return }

        Task {
            do {
                let appUser = try await FirestoreService.shared.getUser(uid: stableUser.uid)

                await MainActor.run {
                    if appUser.disabled {
                        try? AuthService.shared.signOut()
                        self.currentUser = nil
                    } else {
                        self.currentUser = appUser
                    }
                    self.isLoading = false
                    print("✅ currentUser set to:", self.currentUser?.id ?? "nil")
                }
            } catch {
                let newUser = AppUser(
                    id: stableUser.uid,
                    email: stableUser.email,
                    role: .user,
                    createdAt: Date(),
                    disabled: false
                )

                do {
                    try await FirestoreService.shared.createUser(newUser)
                    await MainActor.run {
                        self.currentUser = newUser
                        self.isLoading = false
                        print("✅ created + set currentUser:", newUser.id)
                    }
                } catch {
                    await MainActor.run {
                        self.currentUser = nil
                        self.isLoading = false
                        print("❌ failed to create user doc:", error.localizedDescription)
                    }
                }
            }
        }
    }
}
