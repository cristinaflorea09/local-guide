import SwiftUI

struct CreateTourView: View {
    @EnvironmentObject var appState: AppState

    @State private var title = ""
    @State private var description = ""
    @State private var country = ""
    @State private var city = ""
    @State private var durationMinutes = 120
    @State private var price = "50"
    @State private var maxPeople = 6
    @State private var latitude = ""
    @State private var longitude = ""
    @State private var active = true

    @State private var coverImage: UIImage?
    @State private var isLoading = false
    @State private var message: String?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Create Tour")
                        .font(.largeTitle.bold())
                        .foregroundStyle(.white)
                        .padding(.top, 8)

                    LuxuryCard {
                        VStack(alignment: .leading, spacing: 12) {
                            LuxuryTextField(title: "Title", text: $title)
                            LuxuryTextField(title: "Description", text: $description)
                            Text("Location").font(.caption.weight(.semibold)).foregroundStyle(.secondary)

                            CountryPicker(country: $country)
                            CityPicker(city: $city, country: country)

                            Text("Cover image")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)

                            ImagePicker(image: $coverImage)

                            if let coverImage {
                                Image(uiImage: coverImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(height: 180)
                                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .stroke(Lx.gold.opacity(0.22), lineWidth: 1))
                            }

                            HStack {
                                LuxuryTextField(title: "Latitude (optional)", text: $latitude, keyboard: .decimalPad)
                                LuxuryTextField(title: "Longitude (optional)", text: $longitude, keyboard: .decimalPad)
                            }

                            Stepper("Duration: \(durationMinutes) min", value: $durationMinutes, in: 30...480, step: 30)
                            Stepper("Max people: \(maxPeople)", value: $maxPeople, in: 1...30)
                            LuxuryTextField(title: "Price (€)", text: $price, keyboard: .decimalPad)
                            Toggle("Active", isOn: $active)
                        }
                    }

                    if let message {
                        Text(message)
                            .foregroundStyle(.white.opacity(0.75))
                    }

                    Button {
                        print("Publish tapped")

                        Haptics.medium()
                        Task { await publish() }
                    } label: {
                        if isLoading { ProgressView().tint(.black) } else { Text("Publish") }
                    }
                    .buttonStyle(LuxuryPrimaryButtonStyle())
                    .disabled(isLoading || title.isEmpty || description.isEmpty || city.isEmpty || coverImage == nil)

                    Text("Tip: a high-quality cover image improves bookings.")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))

                    Spacer(minLength: 10)
                }
                .padding(18)
            }
        }
        .navigationTitle("Create")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func publish() async {
        guard let uid = appState.session.firebaseUser?.uid else { return }
        guard let coverImage else {
            message = "Please choose a cover image."
            return
        }

        isLoading = true
        message = nil

        do {
            // 1) Upload cover to Firebase Storage (server-side ACL controlled by Storage rules)
            let coverPath = "tours/\(uid)/\(UUID().uuidString).jpg"
            let url = try await StorageService.shared.uploadJPEG(coverImage, path: coverPath)

            // 2) Create tour with coverPhotoURL
            let tour = Tour(
                id: UUID().uuidString,
                guideId: uid,
                title: title,
                description: description,
                city: city,
                coverPhotoURL: url.absoluteString,
                latitude: Double(latitude),
                longitude: Double(longitude),
                durationMinutes: durationMinutes,
                price: Double(price) ?? 0,
                maxPeople: maxPeople,
                active: active,
                createdAt: Date()
            )
            try await FirestoreService.shared.createTour(tour)

            Haptics.success()
            message = "Tour published ✅"

            // reset
            title = ""
            description = ""
            city = ""
            price = "50"
            latitude = ""
            longitude = ""
            active = true
            self.coverImage = nil
        } catch {
            message = error.localizedDescription
        }

        isLoading = false
    }
}
