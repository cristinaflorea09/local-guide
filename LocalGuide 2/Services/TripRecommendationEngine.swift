import Foundation
import CoreLocation

/// Heuristic matcher that links in-app Tours/Experiences to a generated TripPlan.
///
/// Goals:
/// - Match by interests/category/keywords
/// - Respect budget
/// - Respect group size
/// - Prefer nearby listings (if we have user location and listing coordinates)
/// - Prefer listings with availability within the trip date range
final class TripRecommendationEngine {
    static let shared = TripRecommendationEngine()
    private init() {}

    struct Inputs {
        let city: String
        let country: String?
        let startDate: Date
        let endDate: Date
        let interests: [String]
        let budgetPerDay: Double?
        let pace: String?
        let groupSize: Int?
        let userLocation: CLLocation?
    }

    struct Scored<T> {
        let item: T
        let score: Double
        let availabilityCount: Int
    }

    func recommend(
        inputs: Inputs,
        tours: [Tour],
        experiences: [Experience]
    ) async -> (tourIds: [String], experienceIds: [String]) {
        // 1) Basic filtering (active + city + group size)
        let filteredTours = tours.filter { t in
            t.active && t.city.caseInsensitiveCompare(inputs.city) == .orderedSame
            && (inputs.groupSize == nil || inputs.groupSize! <= t.maxPeople)
        }
        let filteredExps = experiences.filter { e in
            e.active && e.city.caseInsensitiveCompare(inputs.city) == .orderedSame
            && (inputs.groupSize == nil || inputs.groupSize! <= e.maxPeople)
        }

        // 2) Score without availability first to shortlist
        let prelimTours = filteredTours.map { t in
            Scored(item: t, score: baseScoreForTour(t, inputs: inputs), availabilityCount: 0)
        }.sorted { $0.score > $1.score }

        let prelimExps = filteredExps.map { e in
            Scored(item: e, score: baseScoreForExperience(e, inputs: inputs), availabilityCount: 0)
        }.sorted { $0.score > $1.score }

        // 3) Availability enrichment for top candidates (avoid N queries)
        let topTourCandidates = Array(prelimTours.prefix(20))
        let topExpCandidates = Array(prelimExps.prefix(20))

        let enrichedTours = await enrichWithAvailability(tours: topTourCandidates, inputs: inputs)
        let enrichedExps = await enrichWithAvailability(experiences: topExpCandidates, inputs: inputs)

        // 4) Final sort with availability boosted + rating tie-break
        let finalTours = enrichedTours
            .sorted {
                if $0.score == $1.score {
                    return (($0.item.ratingAvg ?? 0), ($0.item.ratingCount ?? 0)) > (($1.item.ratingAvg ?? 0), ($1.item.ratingCount ?? 0))
                }
                return $0.score > $1.score
            }
            .prefix(5)
            .map { $0.item.id }

        let finalExps = enrichedExps
            .sorted {
                if $0.score == $1.score {
                    return (($0.item.ratingAvg ?? 0), ($0.item.ratingCount ?? 0)) > (($1.item.ratingAvg ?? 0), ($1.item.ratingCount ?? 0))
                }
                return $0.score > $1.score
            }
            .prefix(5)
            .map { $0.item.id }

        return (Array(finalTours), Array(finalExps))
    }

    // MARK: - Scoring

    private func baseScoreForTour(_ t: Tour, inputs: Inputs) -> Double {
        var s = 0.0

        // Interest match (category + title/description keywords)
        s += interestScore(
            category: t.category,
            title: t.title,
            description: t.description,
            interests: inputs.interests
        )

        // Budget match
        s += budgetScore(price: t.price, budgetPerDay: inputs.budgetPerDay)

        // Pace vs duration
        s += paceScore(durationMinutes: t.durationMinutes, pace: inputs.pace)

        // Distance (if we have it)
        s += distanceScore(lat: t.latitude, lon: t.longitude, userLoc: inputs.userLocation)

        // Rating baseline
        s += ratingScore(avg: t.ratingAvg, count: t.ratingCount)

        return s
    }

    private func baseScoreForExperience(_ e: Experience, inputs: Inputs) -> Double {
        var s = 0.0
        s += interestScore(
            category: e.category,
            title: e.title,
            description: e.description,
            interests: inputs.interests
        )
        s += budgetScore(price: e.price, budgetPerDay: inputs.budgetPerDay)
        s += paceScore(durationMinutes: e.durationMinutes, pace: inputs.pace)
        s += distanceScore(lat: e.latitude, lon: e.longitude, userLoc: inputs.userLocation)
        s += ratingScore(avg: e.ratingAvg, count: e.ratingCount)
        return s
    }

    private func normalize(_ s: String) -> String {
        s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func interestScore(category: String?, title: String, description: String, interests: [String]) -> Double {
        let ints = interests.map(normalize).filter { !$0.isEmpty }
        guard !ints.isEmpty else { return 0 }

        let cat = normalize(category ?? "")
        let text = normalize(title + " " + description)

        var matches = 0
        for i in ints {
            if cat.contains(i) || text.contains(i) {
                matches += 1
            }
        }
        // Up to +3
        return min(3.0, Double(matches) * 1.0)
    }

    private func budgetScore(price: Double, budgetPerDay: Double?) -> Double {
        guard let b = budgetPerDay, b > 0 else { return 0 }
        // If listing price within daily budget (or up to 20% above), boost.
        if price <= b { return 2.0 }
        if price <= b * 1.2 { return 1.0 }
        // Too expensive -> penalize
        return -1.5
    }

    private func paceScore(durationMinutes: Int, pace: String?) -> Double {
        let p = normalize(pace ?? "")
        switch p {
        case "fast":
            return durationMinutes <= 120 ? 0.8 : -0.4
        case "relaxed":
            return durationMinutes >= 180 ? 0.8 : 0
        default:
            return 0
        }
    }

    private func ratingScore(avg: Double?, count: Int?) -> Double {
        let a = avg ?? 0
        let c = Double(count ?? 0)
        // Small, stable boost. Cap the count influence.
        return min(2.0, a * 0.3 + min(50, c) * 0.01)
    }

    private func distanceScore(lat: Double?, lon: Double?, userLoc: CLLocation?) -> Double {
        guard let userLoc, let lat, let lon else { return 0 }
        let listingLoc = CLLocation(latitude: lat, longitude: lon)
        let km = userLoc.distance(from: listingLoc) / 1000.0
        // Prefer closer. Within 5km: +1.2, within 15km: +0.6
        if km <= 5 { return 1.2 }
        if km <= 15 { return 0.6 }
        if km <= 50 { return 0.1 }
        return -0.4
    }

    // MARK: - Availability enrichment

    private func enrichWithAvailability(
        tours: [Scored<Tour>],
        inputs: Inputs
    ) async -> [Scored<Tour>] {
        await withTaskGroup(of: Scored<Tour>.self) { group in
            for st in tours {
                group.addTask {
                    let count = await self.availabilityCount(listingType: "tour", listingId: st.item.id, inputs: inputs)
                    let boosted = st.score + self.availabilityBoost(count)
                    return Scored(item: st.item, score: boosted, availabilityCount: count)
                }
            }
            var out: [Scored<Tour>] = []
            for await v in group { out.append(v) }
            return out
        }
    }

    private func enrichWithAvailability(
        experiences: [Scored<Experience>],
        inputs: Inputs
    ) async -> [Scored<Experience>] {
        await withTaskGroup(of: Scored<Experience>.self) { group in
            for se in experiences {
                group.addTask {
                    let count = await self.availabilityCount(listingType: "experience", listingId: se.item.id, inputs: inputs)
                    let boosted = se.score + self.availabilityBoost(count)
                    return Scored(item: se.item, score: boosted, availabilityCount: count)
                }
            }
            var out: [Scored<Experience>] = []
            for await v in group { out.append(v) }
            return out
        }
    }

    private func availabilityBoost(_ openCount: Int) -> Double {
        if openCount == 0 { return -0.8 }
        if openCount == 1 { return 0.6 }
        if openCount <= 3 { return 1.2 }
        return 1.6
    }

    private func availabilityCount(listingType: String, listingId: String, inputs: Inputs) async -> Int {
        do {
            let slots = try await FirestoreService.shared.getAvailabilityForListingInRange(
                listingType: listingType,
                listingId: listingId,
                start: inputs.startDate,
                end: inputs.endDate
            )
            // Only count open + not reserved
            return slots.filter { ($0.isReserved ?? false) == false && $0.status == .open }.count
        } catch {
            // If availability isn't configured, don't fail recommendations.
            return 0
        }
    }
}
