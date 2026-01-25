import SwiftUI

struct GuideToursView: View {
    @EnvironmentObject var appState: AppState
    @State private var tours: [Tour] = []
    @State private var isLoading = false

    var body: some View {
        List {
            ForEach(tours) { tour in
                    NavigationLink {
                        SellerTourDetailView(tour: tour)
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(tour.title).font(.headline)
                            Text(tour.description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                            let priceText = String(format: "€%.2f", tour.price)
                            Text("\(tour.city) • \(priceText) • \(tour.active ? "Active" : "Inactive")")
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        NavigationLink {
                            EditTourView(tour: tour)
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        .tint(.blue)
                    }
                }
        }
        .overlay {
            if isLoading { ProgressView("Loading…") }
            if !isLoading && tours.isEmpty { ContentUnavailableView("No tours yet", systemImage: "map") }
        }
        .navigationTitle("My Tours")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    CreateTourView()
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .task { await load() }
        .onReceive(Timer.publish(every: 30, on: .main, in: .common).autoconnect()) { _ in
            Task { await load() }
        }
    }

    private func load() async {
        guard let email = appState.session.firebaseUser?.email else { return }
        isLoading = true
        do { tours = try await FirestoreService.shared.getToursForGuide(guideEmail: email) } catch { tours = [] }
        isLoading = false
    }
}
