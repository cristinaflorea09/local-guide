import SwiftUI

struct CountryPicker: View {
    @Binding var country: String

    var body: some View {
        Menu {
            ForEach(CountryCityData.countries, id: \.self) { c in
                Button(c) { country = c }
            }
        } label: {
            HStack {
                Text(country.isEmpty ? "Select country" : country)
                Spacer()
                Image(systemName: "chevron.down").foregroundStyle(.secondary)
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.10)))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Lx.gold.opacity(0.16), lineWidth: 1))
        }
    }
}

struct CityPicker: View {
    @Binding var city: String
    let country: String

    var body: some View {
        let cities = CountryCityData.citiesByCountry[country] ?? []
        Menu {
            if cities.isEmpty {
                Text("No preset cities for this country yet.").foregroundStyle(.secondary)
            } else {
                ForEach(cities, id: \.self) { c in
                    Button(c) { city = c }
                }
            }
        } label: {
            HStack {
                Text(city.isEmpty ? "Select city" : city)
                Spacer()
                Image(systemName: "chevron.down").foregroundStyle(.secondary)
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.10)))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Lx.gold.opacity(0.16), lineWidth: 1))
        }
        .disabled(country.isEmpty || cities.isEmpty)
    }
}
