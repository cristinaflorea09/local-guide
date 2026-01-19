import SwiftUI

struct AdminGuidesView: View {
    @State private var guides: [GuideProfile] = []
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            List(guides) { g in
                VStack(alignment: .leading, spacing: 4) {
                    Text(g.displayName).font(.headline)
                    Text("\(g.city) • Languages: \(g.languages.joined(separator: ", "))")
                        .foregroundStyle(.secondary)
                }
                .swipeActions {
                    Button("Approve") {
                        Task { await approve(g.id) }
                    }
                    .tint(.green)
                }
            }
            .overlay {
                if isLoading { ProgressView("Loading…") }
                if !isLoading && guides.isEmpty { ContentUnavailableView("No guides", systemImage: "person") }
            }
            .navigationTitle("Guides")
        }
            .onAppear { Task { await load() } }
        }
    

    private func load() async {
        isLoading = true
        do { guides = try await FirestoreService.shared.listGuides() } catch { guides = [] }
        isLoading = false
    }

    private func approve(_ uid: String) async {
        do {
            try await FirestoreService.shared.updateUser(uid: uid, fields: ["guideApproved": true])
            await load()
        } catch { }
    }
}
