import SwiftUI

struct AdminFinanceView: View {
    @EnvironmentObject var appState: AppState

    @State private var isLoading = false
    @State private var error: String?

    @State private var totalGMV: Double = 0
    @State private var totalCommission: Double = 0
    @State private var totalBookings: Int = 0

    @State private var rows: [Row] = []

    struct Row: Identifiable {
        let id: String
        let sellerLabel: String
        let role: String
        let bookings: Int
        let gmv: Double
        let commission: Double
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Finance")
                            .font(.largeTitle.bold())
                            .foregroundStyle(.white)

                        LuxuryCard {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack { Text("Bookings"); Spacer(); Text("\(totalBookings)").foregroundStyle(.secondary) }
                                HStack { Text("GMV"); Spacer(); Text(formatRON(totalGMV)).foregroundStyle(.secondary) }
                                HStack { Text("Estimated commission"); Spacer(); Text(formatRON(totalCommission)).foregroundStyle(.secondary) }
                                Text("Commission estimate uses 15% for Guides and 18% for Hosts by default. Stripe fees not included.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        if isLoading {
                            LuxuryCard { ProgressView("Loading…").tint(Lx.gold) }
                        }

                        if let error {
                            Text(error).foregroundStyle(.red)
                        }

                        LuxuryCard {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Top sellers")
                                    .font(.headline)

                                ForEach(rows.prefix(15)) { r in
                                    HStack(alignment: .firstTextBaseline) {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(r.sellerLabel).font(.subheadline.weight(.semibold))
                                            Text(r.role).font(.caption).foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        VStack(alignment: .trailing, spacing: 2) {
                                            Text(formatRON(r.commission)).font(.subheadline.weight(.semibold))
                                            Text("\(r.bookings) bookings • \(formatRON(r.gmv))").font(.caption).foregroundStyle(.secondary)
                                        }
                                    }
                                    Divider().opacity(0.10)
                                }
                            }
                        }

                        NavigationLink { EarningsSimulatorROView() } label: {
                            Text("Romania earnings simulator")
                        }
                        .buttonStyle(LuxurySecondaryButtonStyle())

                        Spacer(minLength: 18)
                    }
                    .padding(18)
                }
            }
            .navigationTitle("Finance")
            .toolbar {
            }
            .task { await load() }
        }
    }

    private func load() async {
        isLoading = true
        error = nil

        do {
            let bookings = try await FirestoreService.shared.getAllBookings(limit: 1000)
            totalBookings = bookings.count

            // Group by seller (guideId) and fetch their role.
            let grouped = Dictionary(grouping: bookings, by: { $0.guideId })
            var tmpRows: [Row] = []
            var gmvSum: Double = 0
            var commissionSum: Double = 0

            for (sellerId, items) in grouped {
                let seller = try? await FirestoreService.shared.getUser(uid: sellerId)
                let role = seller?.role ?? .guide
                let rate: Double = (role == .host) ? 0.18 : 0.15
                let gmv = items.reduce(0) { $0 + $1.totalPrice }
                let comm = gmv * rate
                gmvSum += gmv
                commissionSum += comm

                let label = seller?.fullName.isEmpty == false ? seller!.fullName : (seller?.email ?? sellerId)
                tmpRows.append(Row(
                    id: sellerId,
                    sellerLabel: label,
                    role: role == .host ? "Host" : "Guide",
                    bookings: items.count,
                    gmv: gmv,
                    commission: comm
                ))
            }

            rows = tmpRows.sorted { $0.commission > $1.commission }
            totalGMV = gmvSum
            totalCommission = commissionSum
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    private func formatRON(_ v: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "RON"
        f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: v)) ?? "RON \(Int(v))"
    }
}
