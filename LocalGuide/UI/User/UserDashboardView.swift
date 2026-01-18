import SwiftUI

struct UserDashboardView: View {
    @EnvironmentObject var appState: AppState
    @State private var upcomingCount: Int = 0
    @State private var isLoading = false
    @State private var topTours: [Tour] = []
    @State private var topExperiences: [Experience] = []

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Home")
                            .font(.largeTitle.bold())
                            .foregroundStyle(.white)
                            .padding(.top, 8)

                        LuxuryCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Discover luxury local experiences")
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                Text("Book with independent Guides & Hosts.")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.7))
                            }
                        }

                        if !topTours.isEmpty || !topExperiences.isEmpty {
                            TopRatedThisWeekCarousel(tours: topTours, experiences: topExperiences)
                        }

                        HStack(spacing: 12) {
                            LuxuryStatCard(title: "Upcoming", value: "\(upcomingCount)")
                            LuxuryStatCard(title: "Plan", value: appState.session.currentUser?.subscriptionPlan == .premium ? "Premium" : "Free")
                        }

                        LuxuryCard {
                            VStack(alignment: .leading, spacing: 12) {
                                NavigationLink { ExploreMarketplaceView() } label: {
                                    HStack { Text("Explore tours & experiences"); Spacer(); Image(systemName: "chevron.right") }
                                }
                                .foregroundStyle(.white)
                                Divider().opacity(0.15)
                                NavigationLink { SubscriptionView() } label: {
                                    HStack { Text("Upgrade / Manage plan"); Spacer(); Image(systemName: "chevron.right") }
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
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        guard let uid = appState.session.firebaseUser?.uid else { return }
        do {
            let bookings = try await FirestoreService.shared.getBookingsForUser(userId: uid)
            upcomingCount = bookings.filter { $0.status != .canceled }.count
            topTours = try await FirestoreService.shared.listTopRatedToursThisWeek(limit: 10)
            topExperiences = try await FirestoreService.shared.listTopRatedExperiencesThisWeek(limit: 10)
        } catch { }
    }
}

private struct TopRatedThisWeekCarousel: View {
    let tours: [Tour]
    let experiences: [Experience]
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Top rated this week")
                .font(.headline)
                .foregroundStyle(.white)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(tours.prefix(5)) { t in
                        NavigationLink {
                            TourDetailsView(tour: t)
                        } label: {
                            MiniCard(title: t.title, subtitle: t.city, score: t.weeklyScore ?? t.weightedScore ?? t.ratingAvg ?? 0)
                        }
                        .buttonStyle(.plain)
                    }
                    ForEach(experiences.prefix(5)) { e in
                        NavigationLink {
                            ExperienceDetailsView(experience: e)
                        } label: {
                            MiniCard(title: e.title, subtitle: e.city, score: e.weeklyScore ?? e.weightedScore ?? e.ratingAvg ?? 0)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }
}

private struct MiniCard: View {
    let title: String
    let subtitle: String
    let score: Double
    var body: some View {
        LuxuryCard {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.65))
                HStack(spacing: 4) {
                    Image(systemName: "star.fill").foregroundStyle(Lx.gold)
                    Text(String(format: "%.2f", score))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.85))
                }
            }
        }
        .frame(width: 210)
    }
}
