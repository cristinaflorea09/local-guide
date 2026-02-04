import SwiftUI

/// Simple tour editor for Guides.
/// Lets sellers update the most important fields without recreating the tour.
struct EditTourView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    let tour: Tour
    let onSave: ((Tour) -> Void)?

    @State private var title: String
    @State private var description: String
    @State private var city: String
    @State private var durationMinutes: Int
    @State private var price: String
    @State private var maxPeople: Int
    @State private var category: String
    @State private var difficulty: String
    @State private var physicalEffort: String
    @State private var authenticityScore: Double
    @State private var latitude: String
    @State private var longitude: String
    @State private var address: String
    @State private var active: Bool

    @State private var coverImage: UIImage?
    @State private var isSaving = false
    @State private var message: String?

    init(tour: Tour, onSave: ((Tour) -> Void)? = nil) {
        self.tour = tour
        self.onSave = onSave
        _title = State(initialValue: tour.title)
        _description = State(initialValue: tour.description)
        _city = State(initialValue: tour.city)
        _durationMinutes = State(initialValue: tour.durationMinutes)
        _price = State(initialValue: String(format: "%.0f", tour.price))
        _maxPeople = State(initialValue: tour.maxPeople)
        _category = State(initialValue: tour.category ?? "Sightseeing")
        _difficulty = State(initialValue: tour.difficulty ?? "Medium")
        _physicalEffort = State(initialValue: tour.physicalEffort ?? "Moderate")
        _authenticityScore = State(initialValue: Double(tour.authenticityScore ?? 50))
        _latitude = State(initialValue: tour.latitude.map { String($0) } ?? "")
        _longitude = State(initialValue: tour.longitude.map { String($0) } ?? "")
        _address = State(initialValue: tour.address ?? "")
        _active = State(initialValue: tour.active)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Edit Tour")
                        .font(.largeTitle.bold())
                        .foregroundStyle(.white)
                        .padding(.top, 8)

                    LuxuryCard {
                        VStack(alignment: .leading, spacing: 12) {
                            LuxuryTextField(title: "Title", text: $title, identifier: "tour_edit_title")
                            LuxuryTextField(title: "Description", text: $description)

                            Text("Category")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Picker("Category", selection: $category) {
                                ForEach(["Sightseeing","Food","Nature","Art","History","Nightlife","Wellness","Adventure"], id: \.self) { c in
                                    Text(c).tag(c)
                                }
                            }
                            .pickerStyle(.menu)

                            HStack {
                                Picker("Difficulty", selection: $difficulty) {
                                    ForEach(["Easy","Medium","Hard"], id: \.self) { Text($0).tag($0) }
                                }
                                .pickerStyle(.menu)

                                Picker("Physical effort", selection: $physicalEffort) {
                                    ForEach(["Low","Moderate","High"], id: \.self) { Text($0).tag($0) }
                                }
                                .pickerStyle(.menu)
                            }

                            VStack(alignment: .leading) {
                                Text("Authenticity score: \(Int(authenticityScore))")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                Slider(value: $authenticityScore, in: 0...100, step: 1)
                            }

                            Text("Location")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            CityPicker(city: $city, country: "")
                            LuxuryTextField(title: "Address (optional)", text: $address)
                            Text("Cover image (optional)")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            ImagePicker(image: $coverImage)

                            Stepper("Duration: \(durationMinutes) min", value: $durationMinutes, in: 30...480, step: 30)
                            Stepper("Max people: \(maxPeople)", value: $maxPeople, in: 1...30)
                            LuxuryTextField(title: "Price (€)", text: $price, keyboard: .decimalPad)
                            Toggle("Active", isOn: $active)

                            HStack {
                                LuxuryTextField(title: "Latitude (optional)", text: $latitude, keyboard: .decimalPad)
                                LuxuryTextField(title: "Longitude (optional)", text: $longitude, keyboard: .decimalPad)
                            }
                        }
                    }

                    if let message {
                        Text(message).foregroundStyle(.white.opacity(0.75))
                    }

                    Button {
                        Haptics.medium()
                        Task { await save() }
                    } label: {
                        if isSaving { ProgressView().tint(.black) } else { Text("Save changes") }
                    }
                    .buttonStyle(LuxuryPrimaryButtonStyle())
                    .disabled(isSaving || title.isEmpty || description.isEmpty || city.isEmpty)
                    .accessibilityIdentifier("tour_edit_save")

                    Spacer(minLength: 12)
                }
                .padding(18)
            }
        }
        .navigationTitle("Edit")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func save() async {
        guard let guideEmail = appState.session.firebaseUser?.email, guideEmail == tour.guideEmail else {
            message = "You can only edit your own tours."
            return
        }

        isSaving = true
        message = nil
        defer { isSaving = false }

        do {
            let updatedPrice = Double(price) ?? tour.price
            var coverURL = tour.coverPhotoURL
            var fields: [String: Any] = [
                "title": title,
                "description": description,
                "city": city,
                "address": address.trimmingCharacters(in: .whitespacesAndNewlines),
                "durationMinutes": durationMinutes,
                "price": updatedPrice,
                "maxPeople": maxPeople,
                "category": category,
                "difficulty": difficulty,
                "physicalEffort": physicalEffort,
                "authenticityScore": Int(authenticityScore),
                "active": active,
                "latitude": Double(latitude) as Any,
                "longitude": Double(longitude) as Any
            ]

            if let coverImage {
                let userEmail = appState.session.firebaseUser?.email ?? tour.guideEmail
                let coverPath = "tours/\(userEmail)/\(UUID().uuidString).jpg"
                let url = try await StorageService.shared.uploadJPEG(coverImage, path: coverPath)
                coverURL = url.absoluteString
                fields["coverPhotoURL"] = coverURL ?? ""
            }

            try await FirestoreService.shared.updateTour(tourId: tour.id, fields: fields)
            Haptics.success()
            let updated = Tour(
                id: tour.id,
                guideEmail: tour.guideEmail,
                title: title,
                description: description,
                city: city,
                country: tour.country,
                address: address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : address,
                coverPhotoURL: coverURL,
                latitude: Double(latitude),
                longitude: Double(longitude),
                durationMinutes: durationMinutes,
                price: updatedPrice,
                maxPeople: maxPeople,
                instantBook: tour.instantBook,
                category: category,
                difficulty: difficulty,
                physicalEffort: physicalEffort,
                authenticityScore: Int(authenticityScore),
                smartPricing: tour.smartPricing,
                ratingAvg: tour.ratingAvg,
                ratingCount: tour.ratingCount,
                weightedScore: tour.weightedScore,
                weeklyScore: tour.weeklyScore,
                cancellationPolicy: tour.cancellationPolicy,
                active: active,
                createdAt: tour.createdAt
            )
            await MainActor.run {
                onSave?(updated)
                dismiss()
            }
        } catch {
            message = error.localizedDescription
        }
    }
}
