import SwiftUI

struct SellerEarningsDashboardView: View {
    @EnvironmentObject var appState: AppState
    @State private var month: Date = Date()
    @State private var bookings: [Booking] = []
    @State private var isLoading = false
    @State private var toast: String?
    @State private var shareURL: URL?

    var body: some View {
        NavigationStack {
            VStack(spacing: 14) {
                monthPicker
                summaryCards
                payoutSection
                reportsSection
                List(bookings) { b in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(b.effectiveListingType.capitalized)
                                .font(.headline)
                            Text(b.startDate.formatted(date: .abbreviated, time: .shortened))
                                .foregroundStyle(.secondary)
                            Text("Status: \(b.status.rawValue)")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4) {
                            Text(String(format: "€%.2f", b.totalPrice))
                                .font(.headline)
                            let fee = (b.applicationFeeMajor as Double?) ?? b.applicationFeeMajor
                            if fee > 0 {
                                Text(String(format: "Fee €%.2f", fee))
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .overlay { if isLoading { ProgressView("Loading…") } }
            .navigationTitle("Earnings")
        }
        .onAppear { Task { await load() } }
        .sheet(item: Binding(get: { shareURL.map(IdentifiedURL.init) }, set: { _ in shareURL = nil })) { item in
            ShareSheet(items: [item.url])
        }
        .alert("", isPresented: Binding(get: { toast != nil }, set: { if !$0 { toast = nil } })) {
            Button("OK", role: .cancel) { toast = nil }
        } message: { Text(toast ?? "") }
    }

    private var monthPicker: some View {
        HStack {
            DatePicker("Month", selection: $month, displayedComponents: [.date])
                .datePickerStyle(.compact)
                .labelsHidden()
            Spacer()
            NavigationLink {
                SellerFinanceSettingsView()
            } label: {
                Label("Tax settings", systemImage: "slider.horizontal.3")
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    private var summaryCards: some View {
        let vatRegistered = appState.session.currentUser?.vatRegistered ?? false
        let vatRate = appState.session.currentUser?.vatRate ?? defaultVatRate()
        let gross = bookings.reduce(0.0) { $0 + $1.totalPrice }
        let fee = bookings.reduce(0.0) { $0 + ($1.applicationFeeMajor) }
        let net = max(0, gross - fee)
        let vat = vatRegistered ? ReportService.shared.computeVATFromGross(gross: gross, vatRate: vatRate) : 0

        return VStack(spacing: 10) {
            HStack(spacing: 10) {
                metricCard(title: "Gross", value: String(format: "€%.2f", gross), icon: "eurosign.circle")
                metricCard(title: "Fee", value: String(format: "€%.2f", fee), icon: "percent")
            }
            HStack(spacing: 10) {
                metricCard(title: "Net", value: String(format: "€%.2f", net), icon: "creditcard")
                metricCard(title: "VAT", value: String(format: "€%.2f", vat), icon: "doc.plaintext")
            }
        }
        .padding(.horizontal)
    }

    private func metricCard(title: String, value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: icon)
                Text(title)
                    .font(.footnote)
                Spacer()
            }
            Text(value)
                .font(.title3.bold())
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var payoutSection: some View {
        NavigationLink {
            StripePayoutCalendarView()
        } label: {
            HStack {
                Image(systemName: "calendar")
                Text("Stripe payout calendar")
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
            }
            .padding(12)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .padding(.horizontal)
    }

    private var reportsSection: some View {
        Button {
            Task {
                do {
                    let user = appState.session.currentUser
                    let name = user?.fullName ?? "Seller"
                    let id = appState.session.firebaseUser?.uid ?? "unknown"
                    let vatRegistered = user?.vatRegistered ?? false
                    let vatRate = user?.vatRate ?? defaultVatRate()
                    let url = try ReportService.shared.generateMonthlyPDF(
                        sellerName: name,
                        sellerId: id,
                        month: month,
                        bookings: bookings,
                        currencySymbol: "€",
                        vatRegistered: vatRegistered,
                        vatRate: vatRate
                    )
                    shareURL = url
                } catch {
                    toast = error.localizedDescription
                }
            }
        } label: {
            HStack {
                Image(systemName: "doc.richtext")
                Text("Export monthly report (PDF)")
                Spacer()
            }
            .padding(12)
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .padding(.horizontal)
    }

    private func defaultVatRate() -> Int {
        // Default: 19% for Romania, 20% common EU fallback.
        let c = (appState.session.currentUser?.country ?? "").lowercased()
        if c.contains("romania") { return 19 }
        return 20
    }

    private func load() async {
        guard let uid = appState.session.firebaseUser?.uid else { return }
        isLoading = true
        defer { isLoading = false }

        let cal = Calendar.current
        let start = cal.date(from: cal.dateComponents([.year, .month], from: month)) ?? month
        let end = cal.date(byAdding: .month, value: 1, to: start)?.addingTimeInterval(-1) ?? month

        do {
            // Pull seller bookings (guide/host). We show confirmed + canceled for a complete tax trail.
            let all = try await FirestoreService.shared.getBookingsForProvider(providerId: uid)
            bookings = all.filter {
                $0.createdAt.map { $0 >= start && $0 <= end } ?? true
            }
        } catch {
            bookings = []
            toast = error.localizedDescription
        }
    }
}

private struct IdentifiedURL: Identifiable {
    let id = UUID()
    let url: URL
    init(_ url: URL) { self.url = url }
}

