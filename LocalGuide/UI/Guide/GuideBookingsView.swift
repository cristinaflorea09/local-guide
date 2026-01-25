import SwiftUI

struct GuideBookingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var bookings: [Booking] = []
    @State private var isLoading = false
    @State private var toast: String?
    @State private var tab: BookingTab = .upcoming

    enum BookingTab: String, CaseIterable, Identifiable {
        case upcoming = "Upcoming"
        case past = "Past"
        var id: String { rawValue }
    }

    var body: some View {
        VStack {
            Picker("", selection: $tab) {
                ForEach(BookingTab.allCases) { t in
                    Text(t.rawValue).tag(t)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            List(filteredBookings) { b in
                VStack(alignment: .leading, spacing: 6) {
                    Text("Status: \(b.status.rawValue)")
                        .font(.headline)
                    Text("Total: €\(b.totalPrice, specifier: "%.2f") • People: \(b.peopleCount)")
                        .foregroundStyle(.secondary)
                    Text("Start: \(b.startDate.formatted(date: .abbreviated, time: .shortened))")
                        .foregroundStyle(.secondary)

                    if b.status == .confirmed && b.isPastEnd {
                        Button {
                            Task {
                                do {
                                    try await StripeConnectService.shared.requestPayoutAfterCompletion(bookingId: b.id)
                                    toast = "Payout requested ✅"
                                } catch {
                                    toast = error.localizedDescription
                                }
                            }
                        } label: {
                            Text("Release payout")
                        }
                        .buttonStyle(LuxurySecondaryButtonStyle())
                    }
                }
            }
        }
        .overlay {
            if isLoading { ProgressView("Loading…") }
            if !isLoading && bookings.isEmpty { ContentUnavailableView("No bookings yet", systemImage: "calendar") }
        }
        .navigationTitle("Bookings")
        .onAppear { Task { await load() } }
        .alert("", isPresented: Binding(get: { toast != nil }, set: { if !$0 { toast = nil } })) {
            Button("OK", role: .cancel) { toast = nil }
        } message: {
            Text(toast ?? "")
        }
    }

    private func load() async {
        guard let uid = appState.session.firebaseUser?.uid else { return }
        guard let providerEmail = appState.session.currentUser?.email else { return }
        isLoading = true
        do {
            bookings = try await FirestoreService.shared.getBookingsForGuide(guideEmail: providerEmail)
        } catch {
            bookings = []
        }
        isLoading = false
    }

    private var filteredBookings: [Booking] {
        switch tab {
        case .upcoming:
            return bookings.filter { !$0.isPastEnd }
        case .past:
            return bookings.filter { $0.isPastEnd }
        }
    }
}
