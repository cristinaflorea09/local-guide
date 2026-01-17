import SwiftUI

struct AccountView: View {
    @EnvironmentObject var appState: AppState
    @State private var saving = false
    @State private var message: String?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(alignment: .leading, spacing: 14) {
                    Text("Account")
                        .font(.largeTitle.bold())
                        .foregroundStyle(.white)

                    if let user = appState.session.currentUser {
                        LuxuryCard {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Text("Name")
                                    Spacer()
                                    Text(user.fullName).foregroundStyle(.secondary)
                                }
                                HStack {
                                    Text("Role")
                                    Spacer()
                                    LuxuryPill(text: user.role.rawValue.uppercased())
                                }

                                Divider().opacity(0.15)

                                Picker("Language", selection: Binding(
                                    get: { appState.settings.languageCode },
                                    set: { newValue in
                                        Task { await saveLanguage(newValue) }
                                    }
                                )) {
                                    Text("English").tag("en")
                                    Text("Romanian").tag("ro")
                                    Text("French").tag("fr")
                                    Text("Spanish").tag("es")
                                    Text("Italian").tag("it")
                                }
                                .pickerStyle(.menu)

                                HStack {
                                    Text("Plan")
                                    Spacer()
                                    Text(user.subscriptionPlan == .premium ? "Premium" : "Free (ads)")
                                        .foregroundStyle(.secondary)
                                }
                                if !appState.subscription.isPremium && user.subscriptionPlan == .premium {
                                    Text("Premium selected — purchase in Premium tab.")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }

                        if user.role == .traveler {
                            NavigationLink { UserProfileEditView() } label: { Text("Edit Profile") }
                                .buttonStyle(LuxurySecondaryButtonStyle())
                        }
                        if user.role == .guide {
                            NavigationLink { GuideProfileEditView() } label: { Text("Edit Guide Profile") }
                                .buttonStyle(LuxurySecondaryButtonStyle())
                        }

                        NavigationLink { SubscriptionView() } label: { Text("Premium") }
                            .buttonStyle(LuxurySecondaryButtonStyle())

                        if let message {
                            Text(message).foregroundStyle(.white.opacity(0.75))
                        }
                    }

                    Button { appState.session.signOut() } label: { Text("Sign Out") }
                        .buttonStyle(LuxurySecondaryButtonStyle())

                    Spacer()
                }
                .padding(18)
            }
        }
    }

    private func saveLanguage(_ code: String) async {
        guard var user = appState.session.currentUser else { return }
        saving = true
        message = nil
        do {
            user.preferredLanguageCode = code
            try await FirestoreService.shared.createUser(user) // merge
            appState.settings.languageCode = code
            Haptics.success()
        } catch {
            message = error.localizedDescription
        }
        saving = false
    }
}
