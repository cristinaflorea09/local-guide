import SwiftUI
import StripePaymentSheet

struct CheckoutView: View {
    @EnvironmentObject var appState: AppState

    let tour: Tour
    let slot: AvailabilitySlot?
    let peopleCount: Int
    let total: Double

    @State private var isLoading = false
    @State private var message: String?
    @State private var paymentSheet: PaymentSheet?
    @State private var presentingSheet = false
    @State private var showBreakdown = false

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
                            Text(tour.title).font(.headline)
                            Text(tour.city).foregroundStyle(.secondary)

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

                            Button {
                                Haptics.light()
                                showBreakdown = true
                            } label: {
                                Text("View price breakdown")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Lx.gold)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
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
        .paymentSheet(isPresented: $presentingSheet, paymentSheet: paymentSheet!, onCompletion: onPaymentCompletion)
        .sheet(isPresented: $showBreakdown) {
            PriceBreakdownSheet(pricePerPerson: tour.price, peopleCount: peopleCount, isPremium: appState.subscription.isPremium)
        }
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
                slotId: slot.id,
                tour: tour,
                date: slot.start,
                peopleCount: peopleCount,
                total: total
            )

            let cents = Int((total * 100.0).rounded())
            let res = try await StripeService.shared.createPaymentIntent(amountCents: cents, currency: AppConfig.stripeCurrency, bookingId: bookingId)

            var configuration = PaymentSheet.Configuration()
            configuration.merchantDisplayName = "LocalGuide"
            paymentSheet = PaymentSheet(paymentIntentClientSecret: res.clientSecret, configuration: configuration)
            presentingSheet = true
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
