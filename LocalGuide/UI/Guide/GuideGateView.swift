import SwiftUI

struct GuideGateView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                if appState.session.isLoading {
                    ProgressView().tint(Lx.gold)
                } else if let user = appState.session.currentUser {
                    if user.guideProfileCreated != true {
                        VStack(spacing: 14) {
                            LuxuryCard {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Complete your guide profile")
                                        .font(.headline)
                                    Text("Add a premium photo, languages, and a short bio to start hosting experiences.")
                                        .foregroundStyle(.secondary)
                                }
                            }

                            NavigationLink {
                                GuideProfileSetupView()
                            } label: {
                                Text("Create profile")
                            }
                            .buttonStyle(LuxuryPrimaryButtonStyle())

                            Spacer()
                        }
                        .padding(18)
                    } else if user.guideApproved != true {
                        VStack(spacing: 14) {
                            LuxuryCard {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Image(systemName: "hourglass.circle.fill").foregroundStyle(Lx.gold)
                                        Text("Pending approval")
                                            .font(.headline)
                                        Spacer()
                                    }
                                    Text("Your profile is created. An admin will approve your account shortly.")
                                        .foregroundStyle(.secondary)
                                }
                            }

                            NavigationLink {
                                GuideProfileEditView()
                            } label: {
                                Text("Edit profile")
                            }
                            .buttonStyle(LuxurySecondaryButtonStyle())

                            Spacer()
                        }
                        .padding(18)
                    } else {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 14) {
                                Text("Guide Home")
                                    .font(.largeTitle.bold())
                                    .foregroundStyle(.white)
                                    .padding(.top, 8)

                                LuxuryCard {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("You’re approved ✅")
                                            .font(.headline)
                                        Text("Create tours, manage availability, and chat with travelers.")
                                            .foregroundStyle(.secondary)
                                    }
                                }

                                NavigationLink { CreateTourView() } label: { Text("Create a tour") }
                                    .buttonStyle(LuxuryPrimaryButtonStyle())

                                NavigationLink { GuideProfileEditView() } label: { Text("Edit profile") }
                                    .buttonStyle(LuxurySecondaryButtonStyle())

                                Spacer(minLength: 10)
                            }
                            .padding(18)
                        }
                    }
                } else {
                    Text("Please login.")
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
        }
    }
}
