import SwiftUI

/// Host-facing list of experiences.
/// Stored in `experiences` collection.
struct HostExperiencesView: View {
    @EnvironmentObject var appState: AppState
    @State private var experiences: [Experience] = []
    @State private var isLoading = false
    @State private var editTarget: Experience?

    enum SortOption: String, CaseIterable, Identifiable {
        case newest = "Newest"
        case bestRated = "Best rated"
        case mostReviews = "Most reviews"
        var id: String { rawValue }
    }

    @State private var sortOption: SortOption = .newest

    private var sorted: [Experience] {
        switch sortOption {
        case .newest:
            return experiences.sorted { $0.createdAt > $1.createdAt }
        case .bestRated:
            // Prefer higher average; break ties by review count.
            return experiences.sorted {
                let la = $0.ratingAvg ?? 0
                let ra = $1.ratingAvg ?? 0
                if la == ra { return ($0.ratingCount ?? 0) > ($1.ratingCount ?? 0) }
                return la > ra
            }
        case .mostReviews:
            return experiences.sorted { ($0.ratingCount ?? 0) > ($1.ratingCount ?? 0) }
        }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(sorted) { exp in
                    NavigationLink {
                        SellerExperienceDetailView(experience: exp)
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(exp.title)
                                .font(.headline)
                            Text(exp.description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                            let priceString = String(format: "%.2f", exp.price)
                            Text("\(exp.city) • €\(priceString) • \(exp.active ? "Active" : "Inactive")")
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button {
                            editTarget = exp
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        .tint(.blue)
                    }
                }
            }
            .overlay {
                if isLoading {
                    ProgressView("Loading…")
                } else if experiences.isEmpty {
                    ContentUnavailableView("No experiences yet", systemImage: "sparkles")
                }
            }
            .navigationTitle("My Experiences")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Picker("Sort", selection: $sortOption) {
                            ForEach(SortOption.allCases) { opt in
                                Text(opt.rawValue).tag(opt)
                            }
                        }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        CreateExperienceView()
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .navigationDestination(item: $editTarget) { exp in
                EditExperienceView(experience: exp)
                    .onDisappear {
                        Task { await load() }
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
        defer { isLoading = false }
        do {
            experiences = try await FirestoreService.shared.getExperiencesForHost(hostEmail: email)
        } catch {
            experiences = []
        }
    }
}

