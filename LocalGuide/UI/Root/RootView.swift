import SwiftUI

struct RootView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Group {
            // Email verification is required for non-admin accounts.
            if appState.session.firebaseUser != nil && !appState.session.isEmailVerified && appState.session.authRoleHint != .admin {
                VerifyEmailView()
            } else if let user = appState.session.currentUser {
                if user.disabled {
                    DisabledAccountView()
                } else {
                    switch user.role {
                    case .admin:
                        AdminHomeView()
                    case .guide:
                        GuideHomeView()
                    case .host:
                        HostHomeView()
                    case .traveler:
                        UserHomeView()
                    }
                }
            } else {
                AuthFlowView(appState: appState, startAt: appState.session.startAuthAtLoginNext ? .login : nil)
            }
        }
        // Force a full SwiftUI tree refresh when language changes.
        .id(appState.settings.languageCode)
        .environment(\.locale, Locale(identifier: appState.settings.languageCode))
        .task {
            appState.session.startListening()
            Task { await appState.subscription.loadProducts() }
            Task { await appState.subscription.refreshEntitlements() }
            Task { try? await StripeService.shared.configureStripe() }
        }
        .onChange(of: appState.session.currentUser?.preferredLanguageCode) { newCode in
            if let code = newCode, !code.isEmpty {
                appState.settings.setLanguage(code)
            }
        }
        .onChange(of: appState.session.firebaseUser) { newVal in
            // Once we reach the logged-out state, consume the flag.
            if newVal == nil && appState.session.startAuthAtLoginNext {
                // leave it set for one render cycle; then clear.
                DispatchQueue.main.async {
                    appState.session.startAuthAtLoginNext = false
                }
            }
        }
    }
}

struct DisabledAccountView: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 10) {
                Image(systemName: "hand.raised.fill").font(.largeTitle).foregroundStyle(Lx.gold)
                Text("Account disabled").font(.title2.bold()).foregroundStyle(.white)
                Text("Please contact support.").foregroundStyle(.white.opacity(0.7))
            }
            .padding()
        }
    }
}
