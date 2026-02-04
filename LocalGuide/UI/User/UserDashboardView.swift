import SwiftUI

struct UserDashboardView: View {
    @EnvironmentObject var appState: AppState
    @State private var upcomingCount: Int = 0
    @State private var isLoading = false
    @State private var isRefreshing = false
    @State private var topTours: [Tour] = []
    @State private var topExperiences: [Experience] = []
    @State private var tripPlans: [TripPlan] = []

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(alignment: .center) {
                            Text("Home")
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
                            Button {
                                Haptics.light()
                                // Bookings lives under the iOS "More" tab for travelers.
                                // Keep this in sync with tags in UserHomeView.
                                appState.travelerTab = 5 // Bookings
                            } label: {
                                LuxuryStatCard(title: "Upcoming", value: "\(upcomingCount)")
                            }
                            .buttonStyle(.plain)

                            LuxuryStatCard(title: "Plan", value: appState.session.currentUser?.subscriptionPlan == .premium ? "Premium" : "Free")
                        }

                        LuxuryCard {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("Your trip plans")
                                        .font(.headline)
                                        .foregroundStyle(.white)
                                    Spacer()
                                    Button {
                                        Haptics.light()
                                        appState.travelerTab = 2 // Plan
                                    } label: {
                                        HStack(spacing: 6) {
                                            Text("New")
                                            Image(systemName: "plus")
                                        }
                                    }
                                    .foregroundStyle(Lx.gold)
                                }

                                if tripPlans.isEmpty {
                                    Text("Create an amazing trip by planning with AI.")
                                        .font(.subheadline)
                                        .foregroundStyle(.white.opacity(0.75))
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                } else {
                                    Divider().opacity(0.15)

                                    ForEach(tripPlans.prefix(3)) { tp in
                                        NavigationLink { TripPlanDetailView(tripPlan: tp) } label: {
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text("\(tp.city), \(tp.country)")
                                                    .foregroundStyle(.white)
                                                Text("\(tp.startDateISO) → \(tp.endDateISO)")
                                                    .font(.caption)
                                                    .foregroundStyle(.white.opacity(0.7))
                                            }
                                        }
                                        .buttonStyle(.plain)

                                        if tp.id != tripPlans.prefix(3).last?.id {
                                            Divider().opacity(0.12)
                                        }
                                    }
                                }
                            }
                        }

                        LuxuryCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Button {
                                    Haptics.light()
                                    appState.travelerTab = 1 // Explore
                                } label: {
                                    HStack { Text("Explore tours & experiences"); Spacer(); Image(systemName: "chevron.right") }
                                }
                                .buttonStyle(.plain)
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
                Task { await load(silent: true) }
            }
        }
    }

    private func load(silent: Bool = false) async {
        if isRefreshing { return }
        isRefreshing = true
        if !silent { isLoading = true }
        defer {
            isRefreshing = false
            if !silent { isLoading = false }
        }
        guard let uid = appState.session.firebaseUser?.uid else { return }
        do {
            let bookings = try await FirestoreService.shared.getBookingsForUser(userId: uid)
            upcomingCount = bookings.filter { $0.status != .canceled }.count
            topTours = try await FirestoreService.shared.listTopRatedToursThisWeek(limit: 10)
            topExperiences = try await FirestoreService.shared.listTopRatedExperiencesThisWeek(limit: 10)
            tripPlans = try await FirestoreService.shared.listTripPlansForUser(uid: uid, limit: 20)
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
                // When there are only 1-2 items, horizontally scrolling stacks
                // tend to center within the available width. Force leading.
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
