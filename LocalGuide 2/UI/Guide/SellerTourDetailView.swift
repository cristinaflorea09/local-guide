import SwiftUI

/// Seller-facing detail view for a tour (read-only preview + edit shortcut).
struct SellerTourDetailView: View {
    let tour: Tour

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    TourCard(tour: tour, subtitle: tour.description)

                    LuxuryCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Details")
                                .font(.headline)
                                .foregroundStyle(.white)
                            Text("City: \(tour.city)").foregroundStyle(.secondary)
                            Text("Duration: \(tour.durationMinutes) min").foregroundStyle(.secondary)
                            Text("Price: €\(tour.price, specifier: "%.2f")").foregroundStyle(.secondary)
                            Text("Max people: \(tour.maxPeople)").foregroundStyle(.secondary)
                            Text("Status: \(tour.active ? "Active" : "Inactive")").foregroundStyle(.secondary)
                        }
                    }

                    NavigationLink {
                        EditTourView(tour: tour)
                    } label: {
                        Text("Edit tour")
                    }
                    .buttonStyle(LuxuryPrimaryButtonStyle())

                    Spacer(minLength: 10)
                }
                .padding(18)
            }
        }
        .navigationTitle("Tour")
        .navigationBarTitleDisplayMode(.inline)
    }
}

