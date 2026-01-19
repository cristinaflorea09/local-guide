import SwiftUI

struct HostGateView: View {
    @EnvironmentObject var appState: AppState
    @State private var hasProfile = false
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                if isLoading {
                    ProgressView().tint(Lx.gold)
                } else {
                    if hasProfile {
                        HostDashboardView()
                    } else {
                        VStack(spacing: 14) {
                            LuxuryCard {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Complete your host profile")
                                        .font(.headline)
                                    Text("Add a premium photo, a short bio and your city to start selling experiences.")
                                        .foregroundStyle(.secondary)
                                }
                            }

                            NavigationLink {
                                HostProfileSetupView()
                            } label: {
                                Text("Create profile")
                            }
                            .buttonStyle(LuxuryPrimaryButtonStyle())

                            Spacer()
                        }
                        .padding(18)
                    }
                }
            }
            .task { await refresh() }
        }
    }

    private func refresh() async {
        guard let uid = appState.session.firebaseUser?.uid else { return }
        isLoading = true
        do {
            _ = try await FirestoreService.shared.getHostProfile(hostId: uid)
            hasProfile = true
        } catch {
            hasProfile = false
        }
        isLoading = false
    }
}
