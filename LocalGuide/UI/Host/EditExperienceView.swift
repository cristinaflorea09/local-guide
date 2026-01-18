import SwiftUI

/// Simple experience editor for Hosts.
struct EditExperienceView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    let experience: Experience

    @State private var title: String
    @State private var description: String
    @State private var country: String
    @State private var city: String
    @State private var durationMinutes: Int
    @State private var price: String
    @State private var maxPeople: Int
    @State private var category: String
    @State private var difficulty: String
    @State private var physicalEffort: String
    @State private var active: Bool

    @State private var newCoverImage: UIImage?
    @State private var isSaving = false
    @State private var message: String?

    init(experience: Experience) {
        self.experience = experience
        _title = State(initialValue: experience.title)
        _description = State(initialValue: experience.description)
        _country = State(initialValue: "")
        _city = State(initialValue: experience.city)
        _durationMinutes = State(initialValue: experience.durationMinutes)
        _price = State(initialValue: String(format: "%.2f", experience.price))
        _maxPeople = State(initialValue: experience.maxPeople)
        _category = State(initialValue: experience.category ?? "")
        _difficulty = State(initialValue: experience.difficulty ?? "")
        _physicalEffort = State(initialValue: experience.physicalEffort ?? "")
        _active = State(initialValue: experience.active)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Edit Experience")
                        .font(.largeTitle.bold())
                        .foregroundStyle(.white)
                        .padding(.top, 8)

                    LuxuryCard {
                        VStack(alignment: .leading, spacing: 12) {
                            LuxuryTextField(title: "Title", text: $title)
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

                            Text("Location")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)

                            CountryPicker(country: $country)
                            CityPicker(city: $city, country: country)

                            Stepper("Duration: \(durationMinutes) min", value: $durationMinutes, in: 30...480, step: 30)
                            Stepper("Max people: \(maxPeople)", value: $maxPeople, in: 1...30)
                            LuxuryTextField(title: "Price (€)", text: $price, keyboard: .decimalPad)
                            Toggle("Active", isOn: $active)

                            Divider().opacity(0.15)
                            Text("Cover image")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)

                            ImagePicker(image: $newCoverImage)
                        }
                    }

                    if let message {
                        Text(message)
                            .foregroundStyle(.white.opacity(0.75))
                    }

                    Button {
                        Haptics.medium()
                        Task { await save() }
                    } label: {
                        if isSaving { ProgressView().tint(.black) } else { Text("Save changes") }
                    }
                    .buttonStyle(LuxuryPrimaryButtonStyle())
                    .disabled(isSaving || title.isEmpty || description.isEmpty || city.isEmpty)

                    Spacer(minLength: 10)
                }
                .padding(18)
            }
        }
        .navigationTitle("Edit")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func save() async {
        guard let uid = appState.session.firebaseUser?.uid else { return }
        guard uid == experience.hostId else {
            message = "You can only edit your own experiences."
            return
        }

        isSaving = true
        message = nil
        defer { isSaving = false }

        do {
            var coverURL = experience.coverPhotoURL
            if let img = newCoverImage {
                let coverPath = "experiences/\(uid)/\(UUID().uuidString).jpg"
                let url = try await StorageService.shared.uploadJPEG(img, path: coverPath)
                coverURL = url.absoluteString
            }

            let fields: [String: Any] = [
                "title": title,
                "description": description,
                "country": country,
                "city": city,
                "durationMinutes": durationMinutes,
                "price": Double(price.replacingOccurrences(of: ",", with: ".")) ?? experience.price,
                "maxPeople": maxPeople,
                "category": category,
                "difficulty": difficulty,
                "physicalEffort": physicalEffort,
                "active": active,
                "coverPhotoURL": coverURL ?? "",
                "updatedAt": Date()
            ]
            try await FirestoreService.shared.updateExperience(experienceId: experience.id, fields: fields)
            Haptics.success()
            await MainActor.run { dismiss() }
        } catch {
            message = error.localizedDescription
        }
    }
}
