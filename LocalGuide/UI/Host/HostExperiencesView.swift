import SwiftUI

/// Host-facing list of experiences.
/// Stored in `experiences` collection.
struct HostExperiencesView: View {
    @EnvironmentObject var appState: AppState
    @State private var experiences: [Experience] = []
    @State private var isLoading = false

    var body: some View {
        List {
            ForEach(experiences) { exp in
                    NavigationLink {
                        SellerExperienceDetailView(experience: exp)
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(exp.title).font(.headline)
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
                        NavigationLink {
                            EditExperienceView(experience: exp)
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        .tint(.blue)
                    }
                }
            }
            .overlay {
                if isLoading { ProgressView("Loading…") }
                if !isLoading && experiences.isEmpty {
                    ContentUnavailableView("No experiences yet", systemImage: "sparkles")
                }
            }
            .navigationTitle("My Experiences")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        CreateExperienceView()
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
        guard let uid = appState.session.firebaseUser?.uid else { return }
        isLoading = true
        do { experiences = try await FirestoreService.shared.getExperiencesForHost(hostId: uid) } catch { experiences = [] }
        isLoading = false
    }
}

