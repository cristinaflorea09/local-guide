import SwiftUI

struct GuideToursView: View {
    @EnvironmentObject var appState: AppState
    @State private var tours: [Tour] = []
    @State private var isLoading = false
    @State private var editTarget: Tour?

    enum SortOption: String, CaseIterable, Identifiable {
        case newest = "Newest"
        case bestRated = "Best rated"
        case mostReviews = "Most reviews"
        var id: String { rawValue }
    }

    @State private var sortOption: SortOption = .newest
    private var sorted: [Tour] {
        switch sortOption {
        case .newest:
            return tours.sorted { $0.createdAt > $1.createdAt }
        case .bestRated:
            // Prefer higher average; break ties by review count.
            return tours.sorted {
                let la = $0.ratingAvg ?? 0
                let ra = $1.ratingAvg ?? 0
                if la == ra { return ($0.ratingCount ?? 0) > ($1.ratingCount ?? 0) }
                return la > ra
            }
        case .mostReviews:
            return tours.sorted { ($0.ratingCount ?? 0) > ($1.ratingCount ?? 0) }
        }
    }
    var body: some View {
        NavigationStack {
            List {
                ForEach(sorted) { tour in
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
                        Button {
                            editTarget = tour
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
            .refreshable { await load() }
        }
    }

    private func load() async {
        guard let email = appState.session.firebaseUser?.email else { return }
        isLoading = true
        do { tours = try await FirestoreService.shared.getToursForGuide(guideEmail: email) } catch { tours = [] }
        isLoading = false
    }
}
