import SwiftUI

struct StripePayoutCalendarView: View {
    @State private var payouts: [StripePayout] = []
    @State private var isLoading = false
    @State private var toast: String?

    var body: some View {
        List(payouts) { p in
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Payout \(p.id.prefix(8))")
                        .font(.headline)
                    Text(p.arrivalDate.formatted(date: .abbreviated, time: .omitted))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Text(p.status.capitalized)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(p.currency.uppercased()) \(p.amountMajor, specifier: "%.2f")")
                    .font(.headline)
            }
        }
        .navigationTitle("Payouts")
        .overlay { if isLoading { ProgressView("Loading…") } }
        .onAppear { Task { await load() } }
        .refreshable { await load() }
        .alert("", isPresented: Binding(get: { toast != nil }, set: { if !$0 { toast = nil } })) {
            Button("OK", role: .cancel) { toast = nil }
        } message: {
            Text(toast ?? "")
        }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            payouts = try await StripeConnectService.shared.listPayouts(limit: 50)
        } catch {
            payouts = []
            toast = error.localizedDescription
        }
    }
}

