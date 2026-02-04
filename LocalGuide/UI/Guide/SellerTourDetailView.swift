import SwiftUI
import FirebaseFirestore

/// Seller-facing detail view for a tour (read-only preview + edit shortcut).
struct SellerTourDetailView: View {
    let tour: Tour
    @State private var currentTour: Tour
    @State private var tourListener: ListenerRegistration?
    @State private var refreshToken = UUID()

    init(tour: Tour) {
        self.tour = tour
        _currentTour = State(initialValue: tour)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    TourCard(tour: currentTour, subtitle: currentTour.description)

                    LuxuryCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Status").font(.headline)
                            Text(currentTour.active ? "Active" : "Inactive")
                                .foregroundStyle(currentTour.active ? Lx.gold : .secondary)

                            Divider().opacity(0.15)

                            Text("Pricing").font(.headline)
                            Text("€\(currentTour.price, specifier: "%.2f") per person")
                                .foregroundStyle(.secondary)
                            Text("Max people: \(currentTour.maxPeople)")
                                .foregroundStyle(.secondary)

                            Divider().opacity(0.15)

                            Text("Category").font(.headline)
                            Text(verbatim: String(describing: currentTour.category ?? "Unknown"))
                                .foregroundStyle(.secondary)
                            Text(verbatim: "Difficulty: \(currentTour.difficulty ?? "Unknown") • Effort: \(currentTour.physicalEffort ?? "Unknown")")
                                .foregroundStyle(.secondary)
                        }
                    }

                    NavigationLink {
                        EditTourView(tour: currentTour) { updated in
                            apply(updated)
                        }
                    } label: {
                        Text("Edit tour")
                    }
                    .buttonStyle(LuxuryPrimaryButtonStyle())
                    .accessibilityIdentifier("tour_detail_edit")

                    Spacer(minLength: 8)
                }
                .id(refreshToken)
                .padding(18)
            }
        }
        .navigationTitle("Details")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { startListening() }
        .onDisappear { stopListening() }
        .task { await load() }
    }

    private func load() async {
        if let latest = try? await FirestoreService.shared.getTour(tourId: tour.id) {
            await MainActor.run { apply(latest) }
        }
    }

    private func startListening() {
        guard tourListener == nil else { return }
        tourListener = FirestoreService.shared.listenToTour(tourId: tour.id) { updated in
            guard let updated else { return }
            Task { @MainActor in
                apply(updated)
            }
        }
    }

    private func stopListening() {
        tourListener?.remove()
        tourListener = nil
    }

    private func apply(_ updated: Tour) {
        currentTour = updated
        refreshToken = UUID()
    }
}
