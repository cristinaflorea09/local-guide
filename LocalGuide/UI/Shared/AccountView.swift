import SwiftUI
import AuthenticationServices
import FirebaseAuth
import UIKit

struct AccountView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.openURL) private var openURL
    @State private var showSellerPlans = false
    @State private var showCustomRequestForm = false
    @State private var showProviderRequests = false
    @State private var showCustomRequestDirectory = false
    @State private var showGuidelines = false
    @State private var showDeleteConfirm = false
    @State private var isDeleting = false
    @State private var deleteError: String?
    @State private var showReauthSheet = false
    @State private var reauthError: String?
    @State private var reauthPassword = ""
    @State private var isReauthenticating = false
    @State private var dataDeleted = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Account")
                        .font(.largeTitle.bold())
                        .foregroundStyle(.white)

                    if let user = appState.session.currentUser {
                        LuxuryCard {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Text("Name")
                                    Spacer()
                                    Text(user.fullName).foregroundStyle(.secondary)
                                }
                                HStack {
                                    Text("Role")
                                    Spacer()
                                    LuxuryPill(text: user.role.rawValue.uppercased())
                                }

                                HStack {
                                    Text("Plan")
                                    Spacer()
                                    Text(user.subscriptionPlan == .premium ? "Premium" : "Free (ads)")
                                        .foregroundStyle(.secondary)
                                }
                                if !appState.subscription.isPremium && user.subscriptionPlan == .premium {
                                    Text("Premium selected — purchase in Premium tab.")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }

                        if user.role == .traveler {
                            NavigationLink { UserProfileEditView() } label: { Text("Edit Profile") }
                                .buttonStyle(LuxurySecondaryButtonStyle())
                        }
                        if user.role == .guide {
                            NavigationLink { GuideProfileEditView() } label: { Text("Edit Guide Profile") }
                                .buttonStyle(LuxurySecondaryButtonStyle())
                        }

                        NavigationLink { SubscriptionView() } label: { Text("Premium") }
                            .buttonStyle(LuxurySecondaryButtonStyle())

                        if user.role == .guide || user.role == .host {
                            Button {
                                showSellerPlans = true
                            } label: {
                                Text("Seller Plans")
                            }
                            .buttonStyle(LuxurySecondaryButtonStyle())
                        }

                        LuxuryCard {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Custom requests").font(.headline)
                                if user.role == .traveler {
                                    Button { showCustomRequestForm = true } label: { Text("Request a custom tour/experience") }
                                        .buttonStyle(LuxurySecondaryButtonStyle())
                                }
                                if user.role == .traveler {
                                    Button { showCustomRequestDirectory = true } label: { Text("Find providers who accept custom requests") }
                                        .buttonStyle(LuxurySecondaryButtonStyle())
                                }
                                if user.role == .guide || user.role == .host {
                                    Button { showProviderRequests = true } label: { Text("View incoming requests") }
                                        .buttonStyle(LuxurySecondaryButtonStyle())
                                }
                            }
                        }

                        if !blockedIds.isEmpty {
                            LuxuryCard {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text("Blocked users").font(.headline)
                                    ForEach(blockedIds, id: \.self) { id in
                                        HStack {
                                            Text(displayId(id))
                                                .foregroundStyle(.secondary)
                                            Spacer()
                                            Button("Unblock") {
                                                Task { await unblockUser(id) }
                                            }
                                            .buttonStyle(.plain)
                                            .foregroundStyle(Lx.gold)
                                        }
                                    }
                                }
                            }
                        }

                        LuxuryCard {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Support").font(.headline)
                                Button {
                                    contactSupport()
                                } label: {
                                    Text("Contact support")
                                }
                                .buttonStyle(LuxurySecondaryButtonStyle())

                                Button {
                                    showGuidelines = true
                                } label: {
                                    Text("Community Guidelines")
                                }
                                .buttonStyle(LuxurySecondaryButtonStyle())

                                if let url = privacyPolicyURL {
                                    Button {
                                        openURL(url)
                                    } label: {
                                        Text("Privacy Policy")
                                    }
                                    .buttonStyle(LuxurySecondaryButtonStyle())
                                } else {
                                    Text("Privacy Policy URL not set.")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }

                    Button { appState.session.signOut() } label: { Text("Sign Out") }
                        .buttonStyle(LuxurySecondaryButtonStyle())
                        .accessibilityIdentifier("account_sign_out")

                    Button {
                        showDeleteConfirm = true
                    } label: {
                        Text(isDeleting ? "Deleting..." : "Delete Account")
                            .font(.headline)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(Color.white.opacity(0.10))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(Color.red.opacity(0.35), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(isDeleting)

                    if let deleteError {
                        Text(deleteError)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }

                    Spacer(minLength: 12)
                }
                .padding(18)
            }
        }
        .fullScreenCover(isPresented: $showSellerPlans) {
            NavigationStack {
                SellerPlansView()
                    .environmentObject(appState)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button {
                                showSellerPlans = false
                            } label: {
                                Image(systemName: "chevron.left")
                            }
                        }
                    }
            }
        }
        .fullScreenCover(isPresented: $showCustomRequestForm) {
            NavigationStack {
                CustomRequestFormView(prefilledProviderEmail: nil)
                    .environmentObject(appState)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) { Button { showCustomRequestForm = false } label: { Image(systemName: "chevron.left") } }
                    }
            }
        }
        .fullScreenCover(isPresented: $showProviderRequests) {
            NavigationStack {
                ProviderCustomRequestsView()
                    .environmentObject(appState)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) { Button { showProviderRequests = false } label: { Image(systemName: "chevron.left") } }
                    }
            }
        }
        .fullScreenCover(isPresented: $showCustomRequestDirectory) {
            NavigationStack {
                CustomRequestDirectoryView()
                    .environmentObject(appState)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) { Button { showCustomRequestDirectory = false } label: { Image(systemName: "chevron.left") } }
                    }
            }
        }
        .fullScreenCover(isPresented: $showGuidelines) {
            NavigationStack {
                CommunityGuidelinesView()
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button { showGuidelines = false } label: { Image(systemName: "chevron.left") }
                        }
                    }
            }
        }
        .confirmationDialog("Delete your account permanently?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete Account", role: .destructive) {
                Task { await deleteAccount() }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will permanently remove your account and all associated data.")
        }
        .sheet(isPresented: $showReauthSheet) {
            NavigationStack {
                ReauthSheet(
                    providers: linkedProviders,
                    email: appState.session.firebaseUser?.email,
                    password: $reauthPassword,
                    isWorking: isReauthenticating,
                    errorMessage: reauthError,
                    onApple: { result, nonce in
                        Task { await handleAppleReauth(result, nonce: nonce) }
                    },
                    onGoogle: {
                        Task { await handleGoogleReauth() }
                    },
                    onPassword: {
                        Task { await handlePasswordReauth() }
                    },
                    onCancel: {
                        showReauthSheet = false
                    }
                )
            }
        }
    }

    private func deleteAccount() async {
        if isDeleting { return }
        guard let firebaseUser = appState.session.firebaseUser else {
            deleteError = "You're not signed in."
            return
        }
        deleteError = nil

        if needsReauth(firebaseUser) {
            showReauthSheet = true
            return
        }
        await performDeletion(user: firebaseUser)
    }

    private var blockedIds: [String] {
        appState.session.currentUser?.blockedUserIds ?? []
    }

    private var privacyPolicyURL: URL? {
        let raw = AppConfig.privacyPolicyURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return nil }
        return URL(string: raw)
    }

    private func contactSupport() {
        let email = AppConfig.supportEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !email.isEmpty, let url = URL(string: "mailto:\(email)") else { return }
        openURL(url)
    }

    private func displayId(_ id: String) -> String {
        if id.contains("@") { return id }
        let prefix = id.prefix(6)
        let suffix = id.suffix(4)
        return "\(prefix)…\(suffix)"
    }

    private func unblockUser(_ blockedId: String) async {
        guard var user = appState.session.currentUser else { return }
        do {
            try await FirestoreService.shared.unblockUser(docId: user.id, blockedId: blockedId)
            var ids = user.blockedUserIds ?? []
            ids.removeAll { $0 == blockedId }
            user.blockedUserIds = ids
            appState.session.currentUser = user
        } catch {
            deleteError = error.localizedDescription
        }
    }

    private func performDeletion(user: User) async {
        if isDeleting { return }
        isDeleting = true
        deleteError = nil
        let email = user.email
        do {
            if !dataDeleted {
                try await FirestoreService.shared.deleteUserData(uid: user.uid, email: email)
                dataDeleted = true
            }
            try await AuthService.shared.deleteCurrentUser()
            appState.session.signOut()
        } catch {
            if requiresRecentLogin(error) {
                showReauthSheet = true
            } else {
                deleteError = error.localizedDescription
            }
        }
        isDeleting = false
    }

    private var linkedProviders: Set<String> {
        let ids = appState.session.firebaseUser?.providerData.map { $0.providerID } ?? []
        return Set(ids)
    }

    private func needsReauth(_ user: User) -> Bool {
        guard let last = user.metadata.lastSignInDate else { return true }
        return Date().timeIntervalSince(last) > 5 * 60
    }

    private func requiresRecentLogin(_ error: Error) -> Bool {
        let nsError = error as NSError
        guard let code = AuthErrorCode(rawValue: nsError.code) else { return false }
        return code == .requiresRecentLogin
    }

    private func handleAppleReauth(_ result: Result<ASAuthorization, Error>, nonce: String?) async {
        reauthError = nil
        switch result {
        case .success(let auth):
            guard let nonce else {
                reauthError = "Apple Sign-In failed. Please try again."
                return
            }
            isReauthenticating = true
            defer { isReauthenticating = false }
            do {
                try await AuthService.shared.reauthenticateWithApple(authorization: auth, rawNonce: nonce)
                showReauthSheet = false
                if let user = appState.session.firebaseUser {
                    await performDeletion(user: user)
                }
            } catch {
                reauthError = error.localizedDescription
            }
        case .failure(let error):
            reauthError = error.localizedDescription
        }
    }

    private func handleGoogleReauth() async {
        reauthError = nil
        guard let presenting = topViewController() else {
            reauthError = "Unable to start Google Sign-In. Please try again."
            return
        }
        isReauthenticating = true
        defer { isReauthenticating = false }
        do {
            try await AuthService.shared.reauthenticateWithGoogle(presenting: presenting)
            showReauthSheet = false
            if let user = appState.session.firebaseUser {
                await performDeletion(user: user)
            }
        } catch {
            reauthError = error.localizedDescription
        }
    }

    private func handlePasswordReauth() async {
        reauthError = nil
        guard let email = appState.session.firebaseUser?.email else {
            reauthError = "Email not available for this account."
            return
        }
        let pwd = reauthPassword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !pwd.isEmpty else {
            reauthError = "Please enter your password."
            return
        }
        isReauthenticating = true
        defer { isReauthenticating = false }
        do {
            try await AuthService.shared.reauthenticateWithPassword(email: email, password: pwd)
            showReauthSheet = false
            reauthPassword = ""
            if let user = appState.session.firebaseUser {
                await performDeletion(user: user)
            }
        } catch {
            reauthError = error.localizedDescription
        }
    }

    private func topViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let keyWindow = scenes.flatMap { $0.windows }.first { $0.isKeyWindow }
        var top = keyWindow?.rootViewController
        while let presented = top?.presentedViewController {
            top = presented
        }
        return top
    }
}

private struct ReauthSheet: View {
    let providers: Set<String>
    let email: String?
    @Binding var password: String
    var isWorking: Bool
    var errorMessage: String?
    var onApple: (Result<ASAuthorization, Error>, String?) -> Void
    var onGoogle: () -> Void
    var onPassword: () -> Void
    var onCancel: () -> Void

    private var showsApple: Bool { providers.contains("apple.com") }
    private var showsGoogle: Bool { providers.contains("google.com") }
    private var showsPassword: Bool { providers.contains("password") }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Confirm your identity")
                        .font(.title3.bold())
                        .foregroundStyle(.white)

                    Text("For your security, please re‑authenticate to delete your account.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))

                    if showsApple {
                        AppleSignInButtonView { result, nonce in
                            onApple(result, nonce)
                        }
                        .disabled(isWorking)
                    }

                    if showsGoogle {
                        GoogleSignInButtonView(isLoading: isWorking, onTap: onGoogle)
                    }

                    if showsPassword {
                        LuxuryCard {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Password")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                SecureField("Enter your password", text: $password)
                                    .textInputAutocapitalization(.never)
                                    .padding(12)
                                    .background(Color.white.opacity(0.06))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                Button("Continue") { onPassword() }
                                    .buttonStyle(LuxuryPrimaryButtonStyle())
                                    .disabled(isWorking || password.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            }
                        }
                    }

                    if !showsApple && !showsGoogle && !showsPassword {
                        Text("No linked sign‑in methods found. Please sign in again and retry.")
                            .foregroundStyle(.white.opacity(0.7))
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }

                    Spacer(minLength: 12)
                }
                .padding(18)
            }
        }
        .navigationTitle("Re‑authenticate")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Close") { onCancel() }
                    .foregroundStyle(.white)
            }
        }
    }
}
