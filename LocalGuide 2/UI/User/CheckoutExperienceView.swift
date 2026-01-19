import SwiftUI
import StripePaymentSheet

struct CheckoutExperienceView: View {
    @EnvironmentObject var appState: AppState

    let experience: Experience
    let slot: AvailabilitySlot?
    let peopleCount: Int
    let total: Double

    @State private var isLoading = false
    @State private var message: String?
    @State private var paymentSheet: PaymentSheet?
    @State private var presentingSheet = false

    private var pricing: PricingBreakdown {
        guard let slot else {
            return PricingBreakdown(basePerPerson: experience.price, peopleCount: peopleCount, appliedPercentOff: 0, appliedLabel: nil, total: Double(peopleCount) * experience.price)
        }
        return PricingEngine.computeTotal(basePerPerson: experience.price, start: slot.start, peopleCount: peopleCount, smartPricing: experience.smartPricing)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Checkout")
                        .font(.largeTitle.bold())
                        .foregroundStyle(.white)

                    LuxuryCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(experience.title).font(.headline)
                            Text(experience.city).foregroundStyle(.secondary)

                            if let s = slot {
                                Text("Time: \(s.start.formatted(date: .abbreviated, time: .shortened)) → \(s.end.formatted(date: .omitted, time: .shortened))")
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("Time: not selected").foregroundStyle(.secondary)
                            }

                            Text("People: \(peopleCount)").foregroundStyle(.secondary)

                            Divider().opacity(0.15)

                            HStack {
                                Text("Total")
                                Spacer()
                                Text("€\(total, specifier: "%.2f")")
                            }
                            .font(.headline)
                        }
                    }

                    if let message {
                        Text(message).foregroundStyle(.white.opacity(0.75))
                    }

                    Button { Haptics.medium(); Task { await startPayment() } } label: {
                        if isLoading { ProgressView() } else { Text("Pay now") }
                    }
                    .buttonStyle(LuxuryPrimaryButtonStyle())
                    .disabled(isLoading || slot == nil)

                    Text("Payments are processed securely by Stripe.")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))

                    Spacer(minLength: 10)
                }
                .padding(18)
            }
        }
        .navigationTitle("Payment")
        .navigationBarTitleDisplayMode(.inline)
        .background(
            Group {
                if let sheet = paymentSheet {
                    EmptyView()
                        .paymentSheet(isPresented: $presentingSheet, paymentSheet: sheet, onCompletion: onPaymentCompletion)
                }
            }
        )
    }

    private func startPayment() async {
        guard appState.session.firebaseUser?.uid != nil else { return }
        guard let slot else {
            message = "Please select an available time slot."
            return
        }

        isLoading = true
        message = nil

        do {
            let bookingId = try await BookingService.shared.reserveSlotAndCreateBooking(
                slot: slot,
                experience: experience,
                peopleCount: peopleCount,
                total: pricing.total
            )

            let res = try await StripeService.shared.createPaymentIntent(bookingId: bookingId)

            var configuration = PaymentSheet.Configuration()
            configuration.merchantDisplayName = "LocalGuide"
            let sheet = PaymentSheet(paymentIntentClientSecret: res.clientSecret, configuration: configuration)
            await MainActor.run {
                paymentSheet = sheet
                DispatchQueue.main.async { presentingSheet = true }
            }
        } catch {
            message = error.localizedDescription
        }

        isLoading = false
    }

    private func onPaymentCompletion(_ result: PaymentSheetResult) {
        switch result {
        case .completed:
            message = "Payment completed ✅. Your booking will confirm shortly."
        case .canceled:
            message = "Payment canceled."
        case .failed(let error):
            message = "Payment failed: \(error.localizedDescription)"
        }
    }
}
