import SwiftUI

struct AccountView: View {
    @EnvironmentObject var appState: AppState

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
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Role")
                                    Spacer()
                                    LuxuryPill(text: user.role.rawValue.uppercased())
                                }
                                if appState.subscription.isPremium {
                                    HStack {
                                        Image(systemName: "crown.fill").foregroundStyle(Lx.gold)
                                        Text("Premium active")
                                            .font(.headline)
                                        Spacer()
                                    }
                                } else {
                                    Text("Premium inactive").foregroundStyle(.secondary)
                                }
                            }
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
}
