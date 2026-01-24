import SwiftUI
import CoreLocation

struct ExploreToursView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var filters: MarketplaceFilterState
    var onSelect: (Tour) -> Void = { _ in }
    @State private var tours: [Tour] = []
    @State private var isLoading = false
    @State private var nextSlotByTourId: [String: Date] = [:]
    @StateObject private var directory = ProfileDirectory()
    @StateObject private var locationManager = LocationManager()

    var body: some View {
        ZStack {
                Color.black.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        if appState.subscription.isPremium {
                            LuxuryCard {
                                HStack {
                                    Image(systemName: "crown.fill").foregroundStyle(Lx.gold)
                                    Text("Premium: 10% off bookings").font(.subheadline.weight(.semibold))
                                    Spacer()
                                }
                            }
                        }

                        if isLoading {
                            LuxuryCard { SkeletonListingRow() }
                            LuxuryCard { SkeletonListingRow() }
                            LuxuryCard { SkeletonListingRow() }
                        }

                        LazyVStack(spacing: 14) {
                            ForEach(sortedAndFilteredTours) { tour in
                                Button {
                                    onSelect(tour)
                                } label: {
                                    TourCard(
                                        tour: tour,
                                        guideName: directory.guide(tour.guideId)?.displayName,
                                        guidePhotoURL: directory.guide(tour.guideId)?.photoURL,
                                        guideRating: directory.guide(tour.guideId)?.ratingAvg,
                                        reviewCount: directory.guide(tour.guideId)?.ratingCount
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        if !isLoading && sortedAndFilteredTours.isEmpty {
                            Text("No tours found.")
                                .foregroundStyle(.white.opacity(0.7))
                                .padding(.top, 8)
                        }
                    }
                    .padding(18).padding(.top, 110)
                }
        }
        .task {
            locationManager.requestPermission()
            await load()
        }
        .onChange(of: filters.city) { _, _ in Task { await load() } }
        .onChange(of: filters.nearMeEnabled) { _, _ in Task { await load() } }
        .onChange(of: filters.nearMeRadiusKm) { _, _ in Task { await load() } }
        .onChange(of: locationManager.lastLocation) { _, _ in
            // When location becomes available, refresh near-me results.
            Task { await load() }
        }
        .onReceive(Timer.publish(every: 30, on: .main, in: .common).autoconnect()) { _ in
            Task { await load() }
        }
    }

    private func load() async {
        isLoading = true
        do {
            // Prefer Near Me (default ON). If location isn't available yet, fall back to regular query.
            if filters.nearMeEnabled, let loc = locationManager.lastLocation {
                let radiusKm = max(1, filters.nearMeRadiusKm)
                let latDelta = radiusKm / 111.0
                let minLat = loc.coordinate.latitude - latDelta
                let maxLat = loc.coordinate.latitude + latDelta

                let candidates = try await FirestoreService.shared.getToursByLatitudeRange(minLat: minLat, maxLat: maxLat, limit: 600)
                tours = candidates.filter { t in
                    guard t.active == true else { return false }
                    guard let lat = t.latitude, let lon = t.longitude else { return false }
                    let d = loc.distance(from: CLLocation(latitude: lat, longitude: lon))
                    return (d / 1000.0) <= radiusKm
                }
            } else {
                // Use server-side city filter when available; all other filters are applied client-side.
                let city = filters.city.trimmingCharacters(in: .whitespacesAndNewlines)
                tours = try await FirestoreService.shared.getTours(city: city.isEmpty ? nil : city)
            }
            for t in tours { await directory.loadGuideIfNeeded(t.guideId) }
            await computeNextSlots()
        } catch {
            tours = []
        }
        isLoading = false
    }

    private var sortedAndFilteredTours: [Tour] {
        let filtered = tours.filter(matchesFilters)
        switch filters.sortOption {
        case .newest:
            return filtered.sorted { $0.createdAt > $1.createdAt }
        case .bestRated:
            return filtered.sorted {
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
            return filtered.sorted {
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
            return filtered.sorted {
                let da = nextSlotByTourId[$0.id] ?? .distantFuture
                let db = nextSlotByTourId[$1.id] ?? .distantFuture
                if da == db {
                    let a = $0.ratingAvg ?? 0
                    let b = $1.ratingAvg ?? 0
                    return a > b
                }
                return da < db
            }
        default:
            return filtered
        }
    }

    private func matchesFilters(_ tour: Tour) -> Bool {
        // Country
        let country = filters.country.trimmingCharacters(in: .whitespacesAndNewlines)
        if !country.isEmpty {
            let tc = (tour.country ?? "").lowercased()
            if !tc.contains(country.lowercased()) { return false }
        }

        // City is handled in fetch, but keep a defensive check too.
        let city = filters.city.trimmingCharacters(in: .whitespacesAndNewlines)
        if !city.isEmpty {
            if !tour.city.lowercased().contains(city.lowercased()) { return false }
        }

        // Text query
        let q = filters.query.trimmingCharacters(in: .whitespacesAndNewlines)
        if !q.isEmpty {
            let hay = (tour.title + " " + tour.description + " " + (tour.category ?? "")).lowercased()
            if !hay.contains(q.lowercased()) { return false }
        }

        // Price
        if let min = filters.priceMin, tour.price < min { return false }
        if let max = filters.priceMax, tour.price > max { return false }

        // Category
        let cat = filters.category.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cat.isEmpty {
            if !(tour.category ?? "").lowercased().contains(cat.lowercased()) { return false }
        }

        // Duration
        if let maxM = filters.duration.maxMinutes, tour.durationMinutes > maxM { return false }

        // Group size
        if let gs = filters.groupSize, tour.maxPeople < gs { return false }

        // Instant book
        if filters.instantBookOnly {
            if tour.instantBook != true { return false }
        }

        // Rating
        let rating = tour.ratingAvg ?? directory.guide(tour.guideId)?.ratingAvg ?? 0
        if rating < filters.minRating { return false }

        return true
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
