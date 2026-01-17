
import SwiftUI

struct UserProfileEditView: View {
    @EnvironmentObject var appState: AppState

    @State private var fullName: String = ""
    @State private var isLoading = false
    @State private var message: String?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Profile")
                        .font(.largeTitle.bold())
                        .foregroundStyle(.white)
                        .padding(.top, 8)

                    LuxuryCard {
                        VStack(alignment: .leading, spacing: 12) {
                            LuxuryTextField(title: "Full name", text: $fullName)

                            Text("This name is shown to guides and on bookings.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if let message {
                        Text(message).foregroundStyle(.white.opacity(0.75))
                    }

                    Button {
                        Task { await save() }
                    } label: {
                        if isLoading { ProgressView().tint(.black) } else { Text("Save") }
                    }
                    .buttonStyle(LuxuryPrimaryButtonStyle())
                    .disabled(isLoading || fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    Spacer(minLength: 12)
                }
                .padding(18)
            }
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .task { load() }
    }

    private func load() {
        fullName = appState.session.currentUser?.fullName ?? ""
    }

    private func save() async {
        guard var user = appState.session.currentUser else { return }

        isLoading = true
        message = nil

        do {
            user.fullName = fullName.trimmingCharacters(in: .whitespacesAndNewlines)
            try await FirestoreService.shared.createUser(user) // merge update
            await appState.session.refreshCurrentUserIfAvailable()
            message = "Saved ✅"
        } catch {
            message = error.localizedDescription
        }

        isLoading = false
    }
}
