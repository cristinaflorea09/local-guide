import SwiftUI

struct HostBookingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var bookings: [Booking] = []
    @State private var isLoading = false
    @State private var toast: String?

    private var upcoming: [Booking] {
        bookings.filter { ($0.status == .confirmed || $0.status == .pendingPayment) && $0.endDate >= Date() }
            .sorted(by: { $0.startDate < $1.startDate })
    }
    private var past: [Booking] {
        bookings.filter { ($0.status == .confirmed || $0.status == .pendingPayment)  && $0.endDate < Date() }
            .sorted(by: { $0.startDate > $1.startDate })
    }

    @State private var segment = 0

    var body: some View {
        NavigationStack {
            VStack {
                Picker("", selection: $segment) {
                    Text("Upcoming").tag(0)
                    Text("Past").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                List(current) { b in
                    NavigationLink {
                        HostBookingDetailView(booking: b, onUpdate: { Task { await load() } })
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Experience booking")
                                .font(.headline)
                            Text(b.startDate.formatted(date: .abbreviated, time: .shortened))
                                .foregroundStyle(.secondary)
                            Text("People: \(b.peopleCount) • Total: \(b.currency.uppercased()) \(String(format: "%.2f", b.totalPrice))")
                                .foregroundStyle(.secondary)
                        }
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

    private var current: [Booking] {
        segment == 0 ? upcoming : past
    }

    private func load() async {
        guard let hostEmail = appState.session.firebaseUser?.email else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            // Experience-only
            bookings = try await FirestoreService.shared.getBookingsForHost(hostEmail: hostEmail)
            print(bookings)
        } catch {
            bookings = []
            toast = error.localizedDescription
        }
    }
}

private struct HostBookingDetailView: View {
    @EnvironmentObject var appState: AppState
    let booking: Booking
    var onUpdate: (() -> Void)?
    @State private var toast: String?
    @State private var isWorking = false

    var body: some View {
        VStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Booking")
                    .font(.title3.bold())
                Text("Date: \(booking.startDate.formatted(date: .abbreviated, time: .shortened))")
                Text("People: \(booking.peopleCount)")
                Text("Total: \(booking.currency.uppercased()) \(String(format: "%.2f", booking.totalPrice))")
                Text("Status: \(booking.status.rawValue)")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 14))

            if booking.status == .confirmed && booking.isPastEnd {
                Button {
                    Task { await releasePayout() }
                } label: {
                    Text("Release payout")
                }
                .buttonStyle(LuxurySecondaryButtonStyle())
            }

            Button(role: .destructive) {
                Task { await cancelBooking() }
            } label: {
                Text("Cancel booking")
            }
            .buttonStyle(LuxurySecondaryButtonStyle())
            .disabled(isWorking)

            Spacer()
        }
        .padding()
        .navigationTitle("Details")
        .alert("", isPresented: Binding(get: { toast != nil }, set: { if !$0 { toast = nil } })) {
            Button("OK", role: .cancel) { toast = nil }
        } message: {
            Text(toast ?? "")
        }
    }

    private func releasePayout() async {
        isWorking = true
        defer { isWorking = false }
        do {
            try await StripeConnectService.shared.requestPayoutAfterCompletion(bookingId: booking.id)
            toast = "Payout requested ✅"
            onUpdate?()
        } catch {
            toast = error.localizedDescription
        }
    }

    private func cancelBooking() async {
        isWorking = true
        defer { isWorking = false }
        do {
            let fn = FirebaseManager.shared.functions.httpsCallable("cancelBooking")
            _ = try await fn.call(["bookingId": booking.id])
            toast = "Canceled ✅"
            onUpdate?()
        } catch {
            toast = error.localizedDescription
        }
    }
}

