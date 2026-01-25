import SwiftUI

/// Seller subscription tiers (Stripe-driven). Used by Guides and Hosts.
struct SellerPlansView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.openURL) private var openURL
    @Environment(\.dismiss) private var dismiss

    @State private var selected: SellerTier = .free
    @State private var isLoading = false
    @State private var message: String?

    private var roleLabel: String {
        switch appState.session.currentUser?.role {
        case .guide: return "Guide"
        case .host: return "Host"
        default: return "Seller"
        }
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("\(roleLabel) Plans")
                        .font(.largeTitle.bold())
                        .foregroundStyle(.white)

                    Text("Choose a tier. You can start free and upgrade any time.")
                        .foregroundStyle(.white.opacity(0.7))

                    planCard(
                        tier: .free,
                        priceRON: 0,
                        commission: (appState.session.currentUser?.role == .host) ? 0.25 : 0.20,
                        bullets: [
                            "Publish listings",
                            "Basic analytics",
                            "Higher commission"
                        ]
                    )

                    planCard(
                        tier: .pro,
                        priceRON: (appState.session.currentUser?.role == .host) ? 129 : 79,
                        commission: (appState.session.currentUser?.role == .host) ? 0.15 : 0.12,
                        bullets: [
                            "Lower commission",
                            "Priority support",
                            "Featured placement (limited)"
                        ]
                    )

                    planCard(
                        tier: .elite,
                        priceRON: (appState.session.currentUser?.role == .host) ? 299 : 199,
                        commission: (appState.session.currentUser?.role == .host) ? 0.08 : 0.07,
                        bullets: [
                            "Lowest commission",
                            "Premium placement",
                            "Early access to new features"
                        ]
                    )

                    if let message {
                        Text(message)
                            .foregroundStyle(.white.opacity(0.75))
                    }

                    Button {
                        Task { await applySelectedPlan() }
                    } label: {
                        if isLoading {
                            ProgressView().tint(.black)
                        } else {
                            Text(selected == .free ? "Switch to Free" : "Continue to Checkout")
                        }
                    }
                    .buttonStyle(LuxuryPrimaryButtonStyle())
                    .disabled(isLoading)

                    Text("Note: Pro/Elite uses Stripe subscription checkout. After payment, your tier is updated via webhook.")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.55))

                    NavigationLink {
                        EarningsSimulatorROView()
                    } label: {
                        Text("Earnings simulator (Romania)")
                    }
                    .buttonStyle(LuxurySecondaryButtonStyle())

                    Spacer(minLength: 12)
                }
                .padding(18)
            }
        }
        .onAppear {
            if let t = appState.session.currentUser?.sellerTier {
                selected = t
            } else {
                selected = .free
            }
        }
    }

    private func planCard(tier: SellerTier, priceRON: Int, commission: Double, bullets: [String]) -> some View {
        Button {
            Haptics.light()
            selected = tier
        } label: {
            LuxuryCard {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(tier.title)
                            .font(.headline)
                        Spacer()
                        if priceRON == 0 {
                            Text("Free")
                                .font(.subheadline.weight(.semibold))
                        } else {
                            Text("\(priceRON) RON / mo")
                                .font(.subheadline.weight(.semibold))
                        }
                    }

                    Text("Commission: \(Int(commission * 100))%")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(bullets, id: \.self) { b in
                            HStack(spacing: 8) {
                                Image(systemName: tier == .free ? "circle" : "checkmark.circle.fill")
                                    .foregroundStyle(Lx.gold)
                                Text(b).font(.subheadline)
                            }
                        }
                    }

                    if selected == tier {
                        HStack {
                            LuxuryPill(text: "Selected")
                            Spacer()
                        }
                    }
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(selected == tier ? Lx.gold.opacity(0.65) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func applySelectedPlan() async {
        guard var user = appState.session.currentUser else { return }
        isLoading = true
        message = nil

        do {
            if selected == .free {
                user.sellerTier = .free
                try await FirestoreService.shared.createUser(user) // merge
                await appState.session.refreshCurrentUserIfAvailable()
                Haptics.success()
                message = "Updated to Free ✅"
            } else {
                // Stripe checkout URL (Cloud Function) — open in Safari.
                let url = try await StripeSellerSubscriptionService.shared.createCheckoutURL(
                    tier: selected,
                    role: user.role
                )
                openURL(url)
                message = "Complete checkout in browser, then return to the app."
            }
        } catch {
            message = error.localizedDescription
        }

        isLoading = false
    }
}

