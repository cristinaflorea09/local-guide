import SwiftUI
import UIKit

struct VerifyEmailView: View {
    @EnvironmentObject var appState: AppState

    @State private var message: String?
    @State private var isBusy = false

    private let pollTimer = Timer.publish(every: 4, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 14) {
                Image(systemName: "envelope.badge")
                    .font(.system(size: 44))
                    .foregroundStyle(Lx.gold)

                Text("auth_verify_title")
                    .font(.title2.bold())
                    .foregroundStyle(.white)

                Text("auth_verify_body")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.horizontal, 22)

                if let message {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.75))
                }

                Button {
                    Task { await resend() }
                } label: {
                    if isBusy { ProgressView().tint(.black) } else { Text("auth_resend") }
                }
                .buttonStyle(LuxurySecondaryButtonStyle())
                .disabled(isBusy)

                Button {
                    appState.session.signOut()
                } label: {
                    Text("auth_signout")
                }
                .buttonStyle(LuxurySecondaryButtonStyle())
                .padding(.top, 6)
            }
            .padding(18)
        }
        .task { await refresh() }
        .onReceive(pollTimer) { _ in
            Task { await refresh() }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            Task { await refresh() }
        }
    }

    private func resend() async {
        isBusy = true
        do {
            try await AuthService.shared.resendEmailVerification()
            message = "Verification email sent."
        } catch {
            message = error.localizedDescription
        }
        isBusy = false
    }

    private func refresh() async {
        guard !isBusy else { return }
        do {
            try await AuthService.shared.reloadCurrentUser()
        } catch {
            // ignore reload errors; user can still verify via email
        }

        if appState.session.isEmailVerified {
            message = "Verified ✅"
            // Return to Login and never show this again on next login.
            appState.session.signOutAndShowLogin()
        } else {
            message = "Waiting for verification…"
        }
    }
}
