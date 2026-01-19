import SwiftUI
import FirebaseFirestore

struct AdminStatsView: View {
    @State private var stats: [String: Int] = [:]
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(stats.keys.sorted(), id: \.self) { key in
                    HStack {
                        Text(key)
                        Spacer()
                        Text("\(stats[key] ?? 0)").foregroundStyle(.secondary)
                    }
                }
            }
            .overlay { if isLoading { ProgressView("Loading…") } }
            .navigationTitle("Stats")
        }
            .onAppear { Task { await load() } }
        }
    

    private func load() async {
        isLoading = true
        let db = FirebaseManager.shared.db
        do {
            let users = try await db.collection("users").getDocuments()
            let tours = try await db.collection("tours").getDocuments()
            let bookings = try await db.collection("bookings").getDocuments()
            stats = [
                "Users": users.count,
                "Tours": tours.count,
                "Bookings": bookings.count
            ]
        } catch {
            stats = [:]
        }
        isLoading = false
    }
}
