import SwiftUI

struct ExploreToursView: View {
    @EnvironmentObject var appState: AppState
    @State private var tours: [Tour] = []
    @State private var isLoading = false
    @State private var cityFilter = ""
    @StateObject private var directory = ProfileDirectory()

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Explore")
                            .font(.largeTitle.bold())
                            .foregroundStyle(.white)
                            .padding(.top, 8)

                        LuxuryCard {
                            HStack(spacing: 10) {
                                Image(systemName: "magnifyingglass")
                                    .foregroundStyle(Lx.gold)
                                TextField("Search by city", text: $cityFilter)
                                    .textInputAutocapitalization(.never)
                                    .foregroundStyle(.primary)
                                Button("Go") { Task { await load() } }
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Lx.gold)
                            }
                        }

                        if appState.subscription.isPremium {
                            LuxuryCard {
                                HStack {
                                    Image(systemName: "crown.fill").foregroundStyle(Lx.gold)
                                    Text("Premium: 10% off bookings").font(.subheadline.weight(.semibold))
                                    Spacer()
                                }
                            }
                        }


                        if !(appState.session.currentUser?.subscriptionPlan == .premium || appState.subscription.isPremium) {
                            AdsBannerView()
                        }

                        if isLoading { ProgressView("Loading…").tint(Lx.gold).padding(.top, 6) }

                        LazyVStack(spacing: 14) {
                            ForEach(tours) { tour in
                                NavigationLink {
                                    TourDetailsView(tour: tour)
                                } label: {
                                    TourCard(tour: tour, guideName: directory.guide(tour.guideId)?.displayName, guidePhotoURL: directory.guide(tour.guideId)?.photoURL, guideRating: directory.guide(tour.guideId)?.ratingAvg, reviewCount: directory.guide(tour.guideId)?.ratingCount)
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        if !isLoading && tours.isEmpty {
                            Text("No tours found.")
                                .foregroundStyle(.white.opacity(0.7))
                                .padding(.top, 8)
                        }
                    }
                    .padding(18)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { Task { await load() } } label: {
                        Image(systemName: "arrow.clockwise").foregroundStyle(Lx.gold)
                    }
                }
            }
            .onAppear { Task { await load() } }
        }
    }

    private func load() async {
        isLoading = true
        do {
            tours = try await FirestoreService.shared.getTours(city: cityFilter.isEmpty ? nil : cityFilter)
            for t in tours { await directory.loadGuideIfNeeded(t.guideId) }
        } catch {
            tours = []
        }
        isLoading = false
    }
}
