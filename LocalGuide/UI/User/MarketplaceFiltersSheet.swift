import SwiftUI

struct MarketplaceFiltersSheet: View {
    @ObservedObject var filters: MarketplaceFilterState
    @Environment(\.dismiss) private var dismiss

    @State private var priceMinText: String = ""
    @State private var priceMaxText: String = ""

    @State private var showCountryPicker = false
    @State private var showCityPicker = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Location") {
                    Button {
                        showCountryPicker = true
                    } label: {
                        HStack {
                            Text("Country")
                            Spacer()
                            Text(filters.country.isEmpty ? "Any" : filters.country)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Button {
                        showCityPicker = true
                    } label: {
                        HStack {
                            Text("City")
                            Spacer()
                            Text(filters.city.isEmpty ? "Any" : filters.city)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Search") {
                    TextField("Keywords (title, description)", text: $filters.query)
                        .textInputAutocapitalization(.never)
                }

                Section("Price range") {
                    HStack {
                        TextField("Min", text: $priceMinText)
                            .keyboardType(.decimalPad)
                        Spacer()
                        TextField("Max", text: $priceMaxText)
                            .keyboardType(.decimalPad)
                    }
                    .onAppear {
                        if let v = filters.priceMin { priceMinText = String(format: "%.0f", v) }
                        if let v = filters.priceMax { priceMaxText = String(format: "%.0f", v) }
                    }
                    .onChange(of: priceMinText) { _, newValue in
                        let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                        filters.priceMin = Double(trimmed)
                    }
                    .onChange(of: priceMaxText) { _, newValue in
                        let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                        filters.priceMax = Double(trimmed)
                    }
                }

                Section("Category") {
                    TextField("Category", text: $filters.category)
                        .textInputAutocapitalization(.words)
                }

                Section("Duration") {
                    Picker("Max duration", selection: $filters.duration) {
                        ForEach(MarketplaceFilterState.DurationPreset.allCases) { d in
                            Text(d.rawValue).tag(d)
                        }
                    }
                }

                Section("Group") {
                    Stepper(value: Binding(get: {
                        filters.groupSize ?? 1
                    }, set: { newValue in
                        filters.groupSize = max(1, newValue)
                    }), in: 1...50) {
                        Text("Group size: \(filters.groupSize ?? 1)")
                    }
                    Toggle("Instant book only", isOn: $filters.instantBookOnly)
                }

                Section("Rating") {
                    Slider(value: $filters.minRating, in: 0...5, step: 0.5)
                    Text("Minimum: \(filters.minRating, specifier: "%.1f")")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Filters")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Clear") {
                        filters.clear()
                        priceMinText = ""
                        priceMaxText = ""
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showCountryPicker) {
                CountryPickerView(country: $filters.country)
            }
            .sheet(isPresented: $showCityPicker) {
                CityPickerView(selectedCountry: filters.country, city: $filters.city)
            }
        }
    }
}
