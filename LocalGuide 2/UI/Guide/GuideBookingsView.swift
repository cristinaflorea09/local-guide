import SwiftUI

struct GuideBookingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var bookings: [Booking] = []
    @State private var isLoading = false
    @State private var toast: String?

    var body: some View {
        NavigationStack {
            List(bookings) { b in
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
            .overlay {
                if isLoading { ProgressView("Loading…") }
                if !isLoading && bookings.isEmpty { ContentUnavailableView("No bookings yet", systemImage: "calendar") }
            }
            .navigationTitle("Bookings")
            }
            .onAppear { Task { await load() } }
            .alert("", isPresented: Binding(get: { toast != nil }, set: { if !$0 { toast = nil } })) {
                Button("OK", role: .cancel) { toast = nil }
            } message: {
                Text(toast ?? "")
            }
        }

    private func load() async {
        guard let uid = appState.session.firebaseUser?.uid else { return }
        isLoading = true
        do { bookings = try await FirestoreService.shared.getBookingsForGuide(guideId: uid) } catch { bookings = [] }
        isLoading = false
    }
}
