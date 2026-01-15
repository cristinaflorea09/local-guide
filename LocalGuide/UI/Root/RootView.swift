import SwiftUI

struct RootView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var session: SessionManager

    var body: some View {
        let _ = print("RootView body recomputed. currentUser:", appState.session.currentUser?.id ?? "nil")

        NavigationStack {
            if let user = appState.session.currentUser {
                if user.role == .admin { AdminHomeView() }
                else if user.role == .guide { GuideHomeView() }
                else { UserHomeView() }
            } else {
                AuthLandingView()   // ✅ default screen
            }
        }
        .overlay {
            if let msg = appState.session.errorMessage {
                VStack(spacing: 8) {
                    Text("Session error").font(.headline)
                    Text(msg).font(.caption).multilineTextAlignment(.center)
                }
                .padding()
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding()
            } else if appState.session.isLoading {
                ProgressView("Loading…")
                    .padding()
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .task {
            appState.session.startListening()

            // Don’t block first screen
            Task { await appState.subscription.loadProducts() }
            Task { await appState.subscription.refreshEntitlements() }
            Task { try? await StripeService.shared.configureStripe() }
        }

    }

}

