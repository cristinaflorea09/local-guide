import SwiftUI

// Reusable searchable pickers for Country and City.
// Uses the same curated destinations list as the Trip Planner.

struct LocationDataset {
    struct Destination: Identifiable, Hashable {
        let id = UUID()
        let city: String
        let country: String
        var label: String { "\(city), \(country)" }
    }

    static let destinations: [Destination] = [
        Destination(city: "Bucharest", country: "Romania"),
        Destination(city: "Cluj-Napoca", country: "Romania"),
        Destination(city: "Brasov", country: "Romania"),
        Destination(city: "Iasi", country: "Romania"),
        Destination(city: "Timisoara", country: "Romania"),
        Destination(city: "Sibiu", country: "Romania"),
        Destination(city: "Constanta", country: "Romania"),
        Destination(city: "Vienna", country: "Austria"),
        Destination(city: "Prague", country: "Czech Republic"),
        Destination(city: "Budapest", country: "Hungary"),
        Destination(city: "Paris", country: "France"),
        Destination(city: "Nice", country: "France"),
        Destination(city: "Rome", country: "Italy"),
        Destination(city: "Milan", country: "Italy"),
        Destination(city: "Barcelona", country: "Spain"),
        Destination(city: "Madrid", country: "Spain"),
        Destination(city: "London", country: "United Kingdom"),
        Destination(city: "Edinburgh", country: "United Kingdom"),
        Destination(city: "Amsterdam", country: "Netherlands"),
        Destination(city: "Berlin", country: "Germany"),
        Destination(city: "Munich", country: "Germany"),
        Destination(city: "Zurich", country: "Switzerland"),
        Destination(city: "Athens", country: "Greece"),
        Destination(city: "Santorini", country: "Greece"),
        Destination(city: "Istanbul", country: "Turkey"),
        Destination(city: "Dubai", country: "United Arab Emirates"),
        Destination(city: "New York", country: "United States"),
        Destination(city: "Los Angeles", country: "United States"),
        Destination(city: "Miami", country: "United States"),
        Destination(city: "Tokyo", country: "Japan"),
        Destination(city: "Kyoto", country: "Japan"),
        Destination(city: "Seoul", country: "South Korea"),
        Destination(city: "Bangkok", country: "Thailand"),
        Destination(city: "Singapore", country: "Singapore")
    ]

    static var countries: [String] {
        Array(Set(destinations.map { $0.country })).sorted()
    }

    static func cities(forCountry country: String?) -> [String] {
        let trimmed = (country ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let dests = trimmed.isEmpty ? destinations : destinations.filter { $0.country.caseInsensitiveCompare(trimmed) == .orderedSame }
        return Array(Set(dests.map { $0.city })).sorted()
    }
}

struct CountryPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var country: String
    @State private var query: String = ""

    private var filtered: [String] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return LocationDataset.countries }
        return LocationDataset.countries.filter { $0.localizedCaseInsensitiveContains(q) }
    }

    var body: some View {
        NavigationStack {
            List {
                Button {
                    country = ""
                    dismiss()
                } label: {
                    Text("Any country")
                }

                ForEach(filtered, id: \.self) { c in
                    Button {
                        country = c
                        dismiss()
                    } label: {
                        Text(c)
                    }
                }
            }
            .navigationTitle("Country")
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}

struct CityPickerView: View {
    @Environment(\.dismiss) private var dismiss
    let selectedCountry: String
    @Binding var city: String
    @State private var query: String = ""

    private var cities: [String] {
        LocationDataset.cities(forCountry: selectedCountry)
    }

    private var filtered: [String] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return cities }
        return cities.filter { $0.localizedCaseInsensitiveContains(q) }
    }

    var body: some View {
        NavigationStack {
            List {
                Button {
                    city = ""
                    dismiss()
                } label: {
                    Text("Any city")
                }

                ForEach(filtered, id: \.self) { c in
                    Button {
                        city = c
                        dismiss()
                    } label: {
                        Text(c)
                    }
                }
            }
            .navigationTitle("City")
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}
