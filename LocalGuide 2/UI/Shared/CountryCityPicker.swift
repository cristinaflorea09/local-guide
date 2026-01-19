import SwiftUI

struct CountryPicker: View {
    @Binding var country: String
    @State private var isPresented = false

    var body: some View {
        Button {
            isPresented = true
        } label: {
            HStack {
                Text(country.isEmpty ? "Select country" : country)
                Spacer()
                Image(systemName: "chevron.down")
                    .foregroundStyle(.secondary)
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.10)))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Lx.gold.opacity(0.16), lineWidth: 1))
        }
        .sheet(isPresented: $isPresented) {
            SearchablePickerSheet(
                title: "Select country",
                items: CountryCityData.countries,
                selected: $country
            )
        }
    }
}

struct CityPicker: View {
    @Binding var city: String
    let country: String
    @State private var isPresented = false

    var body: some View {
        let cities = CountryCityData.citiesByCountry[country] ?? []

        Button {
            isPresented = true
        } label: {
            HStack {
                Text(city.isEmpty ? "Select city" : city)
                Spacer()
                Image(systemName: "chevron.down")
                    .foregroundStyle(.secondary)
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.10)))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Lx.gold.opacity(0.16), lineWidth: 1))
        }
        .disabled(country.isEmpty || cities.isEmpty)
        .opacity((country.isEmpty || cities.isEmpty) ? 0.6 : 1.0)
        .sheet(isPresented: $isPresented) {
            SearchablePickerSheet(
                title: "Select city",
                items: cities,
                selected: $city
            )
        }
        .onChange(of: country) { _ in
            // Clear city when country changes to prevent invalid selections.
            city = ""
        }
    }
}

private struct SearchablePickerSheet: View {
    let title: String
    let items: [String]
    @Binding var selected: String

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var filtered: [String] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if q.isEmpty { return items }
        return items.filter { $0.localizedCaseInsensitiveContains(q) }
    }

    var body: some View {
        NavigationStack {
            List(filtered, id: \.self) { item in
                Button {
                    selected = item
                    dismiss()
                } label: {
                    HStack {
                        Text(item)
                        Spacer()
                        if selected == item {
                            Image(systemName: "checkmark")
                                .foregroundStyle(Lx.gold)
                        }
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
