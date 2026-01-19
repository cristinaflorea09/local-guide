import SwiftUI
import StoreKit

struct SubscriptionView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Premium")
                            .font(.largeTitle.bold())
                            .foregroundStyle(.white)
                            .padding(.top, 8)

                        LuxuryCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(appState.subscription.isPremium ? "Premium active ✅" : "Upgrade to Premium")
                                    .font(.headline)
                                Text("10% off bookings • Priority support • Exclusive experiences")
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Text("Plans")
                            .font(.headline)
                            .foregroundStyle(.white)

                        LazyVStack(spacing: 12) {
                            ForEach(appState.subscription.products, id: \.id) { product in
                                Button {
                                    Task { await appState.subscription.purchase(product) }
                                } label: {
                                    LuxuryCard {
                                        HStack {
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(product.displayName).font(.headline)
                                                Text(product.description).font(.caption).foregroundStyle(.secondary)
                                            }
                                            Spacer()
                                            Text(product.displayPrice)
                                                .font(.headline)
                                                .foregroundStyle(Lx.gold)
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        if let err = appState.subscription.lastError {
                            Text(err).foregroundStyle(.red)
                        }
                    }
                    .padding(18)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Restore") {
                        Task {
                            await appState.subscription.refreshEntitlements()
                        }
                    }
                    .foregroundStyle(Lx.gold)
                }
            }
        }
    }
}
