import Foundation

enum CountryCityData {
    static let countries: [String] = {
        let regions = Locale.Region.isoRegions
        let locale = Locale.current
        let names = regions.compactMap { locale.localizedString(forRegionCode: $0.identifier) }
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
