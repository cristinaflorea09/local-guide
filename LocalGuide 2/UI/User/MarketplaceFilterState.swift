import Foundation

/// Shared search + filters state for the traveler marketplace (Tours + Experiences).
final class MarketplaceFilterState: ObservableObject {
    enum DurationPreset: String, CaseIterable, Identifiable {
        case any = "Any"
        case upTo60 = "Up to 1h"
        case upTo120 = "Up to 2h"
        case upTo240 = "Up to 4h"
        case upTo480 = "Up to 8h"

        var id: String { rawValue }

        var maxMinutes: Int? {
            switch self {
            case .any: return nil
            case .upTo60: return 60
            case .upTo120: return 120
            case .upTo240: return 240
            case .upTo480: return 480
            }
        }
    }

    @Published var query: String = ""

    @Published var country: String = ""
    @Published var city: String = ""

    /// Optional bounds; nil means "Any".
    @Published var priceMin: Double? = nil
    @Published var priceMax: Double? = nil

    @Published var category: String = ""
    @Published var duration: DurationPreset = .any
    @Published var groupSize: Int? = nil
    @Published var instantBookOnly: Bool = false
    @Published var minRating: Double = 0

    @Published var sortOption: ListingSortOption = .bestRated

    func clear() {
        query = ""
        country = ""
        city = ""
        priceMin = nil
        priceMax = nil
        category = ""
        duration = .any
        groupSize = nil
        instantBookOnly = false
        minRating = 0
        sortOption = .bestRated
    }

    var activeFiltersCount: Int {
        var n = 0
        if !country.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { n += 1 }
        if !city.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { n += 1 }
        if priceMin != nil || priceMax != nil { n += 1 }
        if !category.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { n += 1 }
        if duration != .any { n += 1 }
        if groupSize != nil { n += 1 }
        if instantBookOnly { n += 1 }
        if minRating > 0 { n += 1 }
        return n
    }
}
