import SwiftUI

struct UserBookingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var bookings: [Booking] = []
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            List(bookings) { b in
                VStack(alignment: .leading, spacing: 6) {
                    Text("Status: \(b.status.rawValue)").font(.headline)
                    Text("Total: €\(b.totalPrice, specifier: "%.2f") • People: \(b.peopleCount)")
                        .foregroundStyle(.secondary)
                    Text("Date: \(b.date.formatted(date: .abbreviated, time: .shortened))")
                        .foregroundStyle(.secondary)
                }
            }
            .overlay {
                if isLoading { ProgressView("Loading…") }
                if !isLoading && bookings.isEmpty { ContentUnavailableView("No bookings yet", systemImage: "ticket") }
            }
            .navigationTitle("My Bookings")
            .toolbar { Button("Refresh") { Task { await load() } } }
            .onAppear { Task { await load() } }
        }
    }

    private func load() async {
        guard let uid = appState.session.firebaseUser?.uid else { return }
        isLoading = true
        do { bookings = try await FirestoreService.shared.getBookingsForUser(userId: uid) } catch { bookings = [] }
        isLoading = false
    }
}
