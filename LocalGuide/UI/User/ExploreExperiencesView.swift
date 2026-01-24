import SwiftUI
import CoreLocation

struct ExploreExperiencesView: View {
    @EnvironmentObject var filters: MarketplaceFilterState
    var onSelect: (Experience) -> Void = { _ in }
    @State private var experiences: [Experience] = []
    @State private var isLoading = false
    @State private var nextSlotByExpId: [String: Date] = [:]
    @StateObject private var locationManager = LocationManager()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        if isLoading {
                            LuxuryCard { SkeletonListingRow() }
                            LuxuryCard { SkeletonListingRow() }
                            LuxuryCard { SkeletonListingRow() }
                        }

                        LazyVStack(spacing: 14) {
                            ForEach(sortedAndFilteredExperiences) { exp in
                                Button {
                                    onSelect(exp)
                                } label: {
                                    ExperienceCard(experience: exp)
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        if !isLoading && sortedAndFilteredExperiences.isEmpty {
                            Text("No experiences found.")
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

                let candidates = try await FirestoreService.shared.getExperiencesByLatitudeRange(minLat: minLat, maxLat: maxLat, limit: 600)
                experiences = candidates.filter { e in
                    guard e.active == true else { return false }
                    guard let lat = e.latitude, let lon = e.longitude else { return false }
                    let d = loc.distance(from: CLLocation(latitude: lat, longitude: lon))
                    return (d / 1000.0) <= radiusKm
                }
            } else {
                let city = filters.city.trimmingCharacters(in: .whitespacesAndNewlines)
                experiences = try await FirestoreService.shared.getExperiences(city: city.isEmpty ? nil : city)
            }
            await computeNextSlots()
        } catch {
            experiences = []
        }
        isLoading = false
    }

    private var sortedAndFilteredExperiences: [Experience] {
        let filtered = experiences.filter(matchesFilters)
        switch filters.sortOption {
        case .newest:
            return filtered.sorted { $0.createdAt > $1.createdAt }
        case .bestRated:
            return filtered.sorted {
                let a = $0.ratingAvg ?? 0
                let b = $1.ratingAvg ?? 0
                if a == b {
                    let ca = $0.ratingCount ?? 0
                    let cb = $1.ratingCount ?? 0
                    return ca > cb
                }
                return a > b
            }
        case .mostReviewed:
            return filtered.sorted {
                let ca = $0.ratingCount ?? 0
                let cb = $1.ratingCount ?? 0
                if ca == cb {
                    let a = $0.ratingAvg ?? 0
                    let b = $1.ratingAvg ?? 0
                    return a > b
                }
                return ca > cb
            }
        case .soonestAvailable:
            return filtered.sorted {
                let da = nextSlotByExpId[$0.id] ?? .distantFuture
                let db = nextSlotByExpId[$1.id] ?? .distantFuture
                if da == db {
                    return ($0.ratingAvg ?? 0) > ($1.ratingAvg ?? 0)
                }
                return da < db
            }
        default:
            return filtered
        }
    }

    private func matchesFilters(_ exp: Experience) -> Bool {
        // Country
        let country = filters.country.trimmingCharacters(in: .whitespacesAndNewlines)
        if !country.isEmpty {
            let ec = (exp.country ?? "").lowercased()
            if !ec.contains(country.lowercased()) { return false }
        }

        // City is handled in fetch, but keep defensive check
        let city = filters.city.trimmingCharacters(in: .whitespacesAndNewlines)
        if !city.isEmpty {
            if !exp.city.lowercased().contains(city.lowercased()) { return false }
        }

        // Text query
        let q = filters.query.trimmingCharacters(in: .whitespacesAndNewlines)
        if !q.isEmpty {
            let hay = (exp.title + " " + exp.description + " " + (exp.category ?? "")).lowercased()
            if !hay.contains(q.lowercased()) { return false }
        }

        // Price
        if let min = filters.priceMin, exp.price < min { return false }
        if let max = filters.priceMax, exp.price > max { return false }

        // Category
        let cat = filters.category.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cat.isEmpty {
            if !(exp.category ?? "").lowercased().contains(cat.lowercased()) { return false }
        }

        // Duration
        if let maxM = filters.duration.maxMinutes, exp.durationMinutes > maxM { return false }

        // Group size
        if let gs = filters.groupSize, exp.maxPeople < gs { return false }

        // Instant book
        if filters.instantBookOnly {
            if exp.instantBook != true { return false }
        }

        // Rating
        let rating = exp.ratingAvg ?? 0
        if rating < filters.minRating { return false }

        return true
    }

    private func computeNextSlots() async {
        var map: [String: Date] = [:]
        await withTaskGroup(of: (String, Date?).self) { g in
            for e in experiences {
                g.addTask {
                    let slot = try? await FirestoreService.shared.getNextAvailability(listingType: "experience", listingId: e.id)
                    return (e.id, slot?.start)
                }
            }
            for await (id, date) in g {
                if let date { map[id] = date }
            }
        }
        nextSlotByExpId = map
    }
}
