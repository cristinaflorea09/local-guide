import SwiftUI

struct ExploreToursView: View {
    @EnvironmentObject var appState: AppState
    @State private var tours: [Tour] = []
    @State private var isLoading = false
    @State private var cityFilter = ""
    @State private var sortOption: ListingSortOption = .bestRated
    @State private var nextSlotByTourId: [String: Date] = [:]
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

                        LuxuryCard {
                            HStack {
                                Text("Sort")
                                    .foregroundStyle(.white.opacity(0.85))
                                    .font(.subheadline.weight(.semibold))
                                Spacer()
                                Picker("Sort", selection: $sortOption) {
                                    ForEach(ListingSortOption.allCases) { opt in
                                        Text(opt.title).tag(opt)
                                    }
                                }
                                .pickerStyle(.menu)
                                .tint(Lx.gold)
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
                            ForEach(sortedTours) { tour in
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
            }
            .task { await load() }
            .onReceive(Timer.publish(every: 30, on: .main, in: .common).autoconnect()) { _ in
                Task { await load() }
            }
        }
    }

    private func load() async {
        isLoading = true
        do {
            tours = try await FirestoreService.shared.getTours(city: cityFilter.isEmpty ? nil : cityFilter)
            for t in tours { await directory.loadGuideIfNeeded(t.guideId) }
            await computeNextSlots()
        } catch {
            tours = []
        }
        isLoading = false
    }

    private var sortedTours: [Tour] {
        switch sortOption {
        case .newest:
            return tours.sorted { $0.createdAt > $1.createdAt }
        case .bestRated:
            return tours.sorted {
                let a = $0.ratingAvg ?? directory.guide($0.guideId)?.ratingAvg ?? 0
                let b = $1.ratingAvg ?? directory.guide($1.guideId)?.ratingAvg ?? 0
                if a == b {
                    let ca = $0.ratingCount ?? directory.guide($0.guideId)?.ratingCount ?? 0
                    let cb = $1.ratingCount ?? directory.guide($1.guideId)?.ratingCount ?? 0
                    return ca > cb
                }
                return a > b
            }
        case .mostReviewed:
            return tours.sorted {
                let ca = $0.ratingCount ?? directory.guide($0.guideId)?.ratingCount ?? 0
                let cb = $1.ratingCount ?? directory.guide($1.guideId)?.ratingCount ?? 0
                if ca == cb {
                    let a = $0.ratingAvg ?? directory.guide($0.guideId)?.ratingAvg ?? 0
                    let b = $1.ratingAvg ?? directory.guide($1.guideId)?.ratingAvg ?? 0
                    return a > b
                }
                return ca > cb
            }
        case .soonestAvailable:
            return tours.sorted {
                let da = nextSlotByTourId[$0.id] ?? .distantFuture
                let db = nextSlotByTourId[$1.id] ?? .distantFuture
                if da == db {
                    let a = $0.ratingAvg ?? 0
                    let b = $1.ratingAvg ?? 0
                    return a > b
                }
                return da < db
            }
        case .topThisWeek:
            return tours.sorted {_,_ in 
                true
            }
        case .bestWeighted:
            return tours.sorted {_,_ in 
                true
            }
        }
    }

    private func computeNextSlots() async {
        var map: [String: Date] = [:]
        await withTaskGroup(of: (String, Date?).self) { g in
            for t in tours {
                g.addTask {
                    let slot = try? await FirestoreService.shared.getNextAvailability(listingType: "tour", listingId: t.id)
                    return (t.id, slot?.start)
                }
            }
            for await (id, date) in g {
                if let date { map[id] = date }
            }
        }
        nextSlotByTourId = map
    }
}
