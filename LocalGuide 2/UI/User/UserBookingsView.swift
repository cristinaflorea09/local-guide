import SwiftUI

struct UserBookingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var bookings: [Booking] = []
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            List(bookings) { b in
                NavigationLink {
                    UserBookingDetailView(booking: b)
                } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(b.effectiveListingType.capitalized)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Lx.gold)
                        Text("Status: \(b.status.rawValue)")
                            .font(.headline)
                        Text("Total: \(b.currency.uppercased()) \(String(format: "%.2f", b.totalPrice)) • People: \(b.peopleCount)")
                            .foregroundStyle(.secondary)
                        Text("Start: \(b.startDate.formatted(date: .abbreviated, time: .shortened))")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .overlay {
                if isLoading { ProgressView("Loading…") }
                if !isLoading && bookings.isEmpty { ContentUnavailableView("No bookings yet", systemImage: "ticket") }
            }
            .navigationTitle("My Bookings")
            }
            .onAppear { Task { await load() } }
        }

    private func load() async {
        guard let uid = appState.session.firebaseUser?.uid else { return }
        isLoading = true
        do { bookings = try await FirestoreService.shared.getBookingsForUser(userId: uid) } catch { bookings = [] }
        isLoading = false
    }
}

