import SwiftUI

struct AdminUsersView: View {
    @State private var users: [AppUser] = []
    @State private var isLoading = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            List(users) { u in
                VStack(alignment: .leading, spacing: 4) {
                    Text(u.email ?? u.id).font(.headline)
                    Text("Role: \(u.role.rawValue) • Disabled: \(u.disabled ? "Yes" : "No")")
                        .foregroundStyle(.secondary)
                }
                .swipeActions {
                    Button(u.disabled ? "Enable" : "Disable") {
                        Task { await toggleDisabled(u) }
                    }
                    .tint(u.disabled ? .green : .red)
                }
            }
            .overlay {
                if isLoading { ProgressView("Loading…") }
                if !isLoading && users.isEmpty { ContentUnavailableView("No users", systemImage: "person") }
            }
            .navigationTitle("Users")
            .toolbar {
                Button("Refresh") { Task { await load() } }
            }
            .onAppear { Task { await load() } }
        }
    }

    private func load() async {
        isLoading = true
        error = nil

        do {
            users = try await FirestoreService.shared.listUsers()
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    private func toggleDisabled(_ user: AppUser) async {
        do {
            try await FirestoreService.shared.updateUser(uid: user.id, fields: ["disabled": !user.disabled])
            await load()
        } catch { }
    }
}
