import SwiftUI
import FirebaseFirestore

/// Host-facing list of experiences.
/// Stored in `experiences` collection.
struct HostExperiencesView: View {
    @EnvironmentObject var appState: AppState
    @State private var experiences: [Experience] = []
    @State private var isLoading = false
    @State private var editTarget: Experience?
    @State private var lastDoc: DocumentSnapshot?
    @State private var hasMore = true
    @State private var isLoadingMore = false
    private let pageSize = 20

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
                if hasMore {
                    HStack {
                        Spacer()
                        if isLoadingMore {
                            ProgressView()
                        } else {
                            Button("Load more") { Task { await loadMore() } }
                                .disabled(isLoading || lastDoc == nil)
                        }
                        Spacer()
                    }
                }
            }
            .overlay {
                if isLoading && experiences.isEmpty {
                    ProgressView("Loading…")
                } else if !isLoading && experiences.isEmpty {
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
                    .accessibilityIdentifier("host_experience_create")
                }
            }
            .navigationDestination(item: $editTarget) { exp in
                EditExperienceView(experience: exp)
                    .onDisappear {
                        Task { await load() }
                    }
            }
            .task { await load() }
            .onAppear { Task { await load() } }
            .refreshable { await load() }
        }
    }

    private func load() async {
        guard let email = appState.session.firebaseUser?.email else { return }
        if let cached = appState.cachedHostExperiences[email], !cached.isEmpty {
            experiences = cached
            hasMore = cached.count >= pageSize
        }
        isLoading = true
        defer { isLoading = false }
        do {
            let result = try await FirestoreService.shared.getExperiencesForHostPage(
                hostEmail: email,
                limit: pageSize,
                startAfter: nil
            )
            experiences = result.items
            lastDoc = result.last
            hasMore = result.items.count == pageSize
            appState.cachedHostExperiences[email] = experiences
        } catch {
            if experiences.isEmpty { experiences = [] }
            hasMore = false
        }
    }

    private func loadMore() async {
        guard let email = appState.session.firebaseUser?.email else { return }
        guard hasMore, !isLoadingMore else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        do {
            let result = try await FirestoreService.shared.getExperiencesForHostPage(
                hostEmail: email,
                limit: pageSize,
                startAfter: lastDoc
            )
            if !result.items.isEmpty {
                experiences.append(contentsOf: result.items)
            }
            lastDoc = result.last
            hasMore = result.items.count == pageSize
            appState.cachedHostExperiences[email] = experiences
        } catch { }
    }
}
