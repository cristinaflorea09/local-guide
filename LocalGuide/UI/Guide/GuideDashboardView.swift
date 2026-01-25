import SwiftUI

/// Guide dashboard shown once the guide is approved.
/// Kept visually similar to `HostDashboardView`.
struct GuideDashboardView: View {
    @EnvironmentObject var appState: AppState
    @State private var bookingsCount: Int = 0
    @State private var toursCount: Int = 0
    @State private var isLoading = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("Guide Dashboard")
                            .font(.largeTitle.bold())
                            .foregroundStyle(.white)
                        Spacer()
                        AvatarView(
                            url: appState.session.currentUser?.photoURL
                                ?? appState.session.firebaseUser?.photoURL?.absoluteString,
                            size: 44
                        )
                    }
                    .padding(.top, 8)

                    LuxuryCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("You are a Guide")
                                .font(.headline)
                                .foregroundStyle(.white)
                            Text("Create premium tours, manage availability, and chat with travelers.")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.7))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }

                    StripePayoutSetupCard()

                    HStack(spacing: 12) {
                        Button {
                            Haptics.light()
                            appState.guideTab = 1 // Tours tab
                        } label: {
                            LuxuryStatCard(title: "Tours", value: "\(toursCount)")
                        }
                        .buttonStyle(.plain)

                        Button {
                            Haptics.light()
                            // Bookings is tag 2 in GuideHomeView
                            appState.guideTab = 2
                        } label: {
                            LuxuryStatCard(title: "Bookings", value: "\(bookingsCount)")
                        }
                        .buttonStyle(.plain)
                    }

                    LuxuryCard {
                        VStack(alignment: .leading, spacing: 12) {
                            NavigationLink { CreateTourView() } label: {
                                HStack {
                                    Text("Create a tour")
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                }
                            }
                            .foregroundStyle(.white)

                            Divider().opacity(0.15)

                            NavigationLink { GuideProfileEditView() } label: {
                                HStack {
                                    Text("Edit Guide Profile")
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
        .onReceive(Timer.publish(every: 30, on: .main, in: .common).autoconnect()) { _ in
            Task { await load() }
        }
    }

    private func load() async {
        if isLoading { return }
        isLoading = true
        defer { isLoading = false }
        guard let email = appState.session.firebaseUser?.email else { return }
        do { toursCount = (try await FirestoreService.shared.getToursForGuide(guideEmail: email)).count } catch { }
        do { bookingsCount = (try await FirestoreService.shared.getBookingsForGuide(guideEmail: email)).count } catch { }
    }
}
