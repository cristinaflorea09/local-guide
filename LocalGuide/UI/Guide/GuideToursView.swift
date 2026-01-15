import SwiftUI

struct GuideToursView: View {
    @EnvironmentObject var appState: AppState
    @State private var tours: [Tour] = []
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            List(tours) { tour in
                VStack(alignment: .leading, spacing: 6) {
                    Text(tour.title).font(.headline)
                    Text("\(tour.city) • €\(tour.price, specifier: "%.2f") • \(tour.active ? "Active" : "Inactive")")
                        .foregroundStyle(.secondary)
                }
            }
            .overlay {
                if isLoading { ProgressView("Loading…") }
                if !isLoading && tours.isEmpty { ContentUnavailableView("No tours yet", systemImage: "map") }
            }
            .navigationTitle("My Tours")
            .toolbar {
                Button("Refresh") { Task { await load() } }
            }
            .onAppear { Task { await load() } }
        }
    }

    private func load() async {
        guard let uid = appState.session.firebaseUser?.uid else { return }
        isLoading = true
        do { tours = try await FirestoreService.shared.getToursForGuide(guideId: uid) } catch { tours = [] }
        isLoading = false
    }
}
