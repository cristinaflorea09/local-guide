import Foundation

enum CountryCityData {
    static let countries: [String] = {
        let locale = Locale.current
        // Build localized country names from region codes
        let names: [String] = Locale.Region.isoRegions.compactMap { region in
            // Use the region's identifier (e.g., "US", "GB") to localize the name
            let code = region.identifier
            return locale.localizedString(forRegionCode: code)
        }
        // Deduplicate and sort
        return Array(Set(names)).sorted()
    }()

    // Lightweight starter set (extend by editing this dictionary or loading JSON)
    static let citiesByCountry: [String: [String]] = [
        "United States": ["New York", "Los Angeles", "Chicago", "Miami", "San Francisco"],
        "United Kingdom": ["London", "Manchester", "Edinburgh", "Birmingham"],
        "France": ["Paris", "Nice", "Lyon", "Marseille"],
        "Italy": ["Rome", "Milan", "Florence", "Venice"],
        "Spain": ["Barcelona", "Madrid", "Valencia", "Seville"],
        "Romania": ["Bucharest", "Cluj-Napoca", "Timisoara", "Iasi", "Brasov"],
        "Germany": ["Berlin", "Munich", "Hamburg", "Cologne"],
        "Netherlands": ["Amsterdam", "Rotterdam", "Utrecht"],
        "Greece": ["Athens", "Santorini", "Thessaloniki"]
    ]
}
