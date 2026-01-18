import SwiftUI

/// A small card prompting Guides/Hosts to connect Stripe Express payouts.
struct StripePayoutSetupCard: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.openURL) private var openURL
    @State private var toast: String?
    @State private var isLoading = false

    var body: some View {
        Group {
            if needsConnect {
                LuxuryCard {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Image(systemName: "banknote.fill")
                                .foregroundStyle(Lx.gold)
                            Text("Payout setup")
                                .font(.headline)
                            Spacer()
                        }

                        Text("To receive payments, connect your Stripe Express account.")
                            .foregroundStyle(.secondary)

                        Button {
                            Task {
                                isLoading = true
                                defer { isLoading = false }
                                do {
                                    let url = try await StripeConnectService.shared.createExpressOnboardingLink()
                                    openURL(url)
                                } catch {
                                    toast = error.localizedDescription
                                }
                            }
                        } label: {
                            if isLoading {
                                HStack(spacing: 8) {
                                    ProgressView().tint(.white)
                                    Text("Opening…")
                                }
                            } else {
                                Text("Connect Stripe")
                            }
                        }
                        .buttonStyle(LuxuryPrimaryButtonStyle())

                        Text("You can complete verification later, but payouts will be blocked until Stripe verification is complete.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .alert("", isPresented: Binding(get: { toast != nil }, set: { if !$0 { toast = nil } })) {
                    Button("OK", role: .cancel) { toast = nil }
                } message: {
                    Text(toast ?? "")
                }
            }
        }
    }
}

private extension StripePayoutSetupCard {
    var needsConnect: Bool {
        guard let u = appState.session.currentUser else { return false }
        return (u.role == .guide || u.role == .host) && (u.stripeAccountId == nil || u.stripeAccountId?.isEmpty == true)
    }
}
