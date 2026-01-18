import SwiftUI

struct HostDashboardView: View {
    @EnvironmentObject var appState: AppState
    @State private var bookingsCount: Int = 0
    @State private var experiencesCount: Int = 0
    @State private var isLoading = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Host Dashboard")
                        .font(.largeTitle.bold())
                        .foregroundStyle(.white)
                        .padding(.top, 8)

                    LuxuryCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("You are a Host")
                                .font(.headline)
                                .foregroundStyle(.white)
                            Text("Sell cultural experiences like workshops, tastings, classes.")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.7))
                        }
                    }

                    StripePayoutSetupCard()

                    HStack(spacing: 12) {
                        LuxuryStatCard(title: "Experiences", value: "\(experiencesCount)")
                        LuxuryStatCard(title: "Bookings", value: "\(bookingsCount)")
                    }

                    LuxuryCard {
                        VStack(alignment: .leading, spacing: 12) {
                            NavigationLink { CreateExperienceView() } label: {
                                HStack {
                                    Text("Create experience")
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                }
                            }
                            .foregroundStyle(.white)
                            Divider().opacity(0.15)
                            NavigationLink { HostProfileEditView() } label: {
                                HStack {
                                    Text("Edit Host Profile")
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                }
                            }
                            .foregroundStyle(.white)
                            Divider().opacity(0.15)
                            NavigationLink { SellerPlansView() } label: {
                                HStack {
                                    Text("Seller plans")
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                }
                            }
                            .foregroundStyle(.white)
                        }
                    }

                    if isLoading { ProgressView().tint(Lx.gold) }

                    Spacer(minLength: 12)
                }
                .padding(18)
            }
        }
        .task { await load() }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        guard let uid = appState.session.firebaseUser?.uid else { return }
        do {
            experiencesCount = (try await FirestoreService.shared.getExperiencesForHost(hostId: uid)).count
        } catch { }
        do {
            bookingsCount = (try await FirestoreService.shared.getBookingsForGuide(guideId: uid)).count
        } catch { }
    }
}

struct LuxuryStatCard: View {
    let title: String
    let value: String

    var body: some View {
        LuxuryCard {
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                Text(value).font(.title2.bold()).foregroundStyle(.white)
            }
        }
    }
}
