import SwiftUI
import CoreLocation

/// Host-facing experience creation.
/// Stored in `experiences` collection.
struct CreateExperienceView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var description = ""
    @State private var country = ""
    @State private var city = ""
    @State private var address = ""
    @State private var durationMinutes = 120
    @State private var price = "50"
    @State private var maxPeople = 6
    @State private var category = "Sightseeing"
    @State private var difficulty = "Easy"
    @State private var physicalEffort = "Low"
    @State private var authenticityScore: Double = 80
    @State private var latitude = ""
    @State private var longitude = ""
    @State private var active = true

    @State private var cancellationPolicy = CancellationPolicy()

    // Smart pricing / promo
    @State private var promoPercent = 0
    @State private var promoStart = Date()
    @State private var promoEnd = Date().addingTimeInterval(7*24*3600)
    @State private var lastMinuteHours = 24
    @State private var lastMinutePercent = 0
    @State private var groupMinPeople = 4
    @State private var groupPercent = 0

    // Fixed schedule sessions (optional). If empty, host can manage slots later.
    @State private var sessions: [Date] = []
    @State private var newSessionDate = Date()
    @State private var repeatWeekly = false
    @State private var repeatWeeks = 0

    @State private var coverImage: UIImage?
    @State private var isLoading = false
    @State private var message: String?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Create Experience")
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
                                ForEach(["Sightseeing","Cooking","Nature","Art","History","Nightlife","Wellness","Adventure"], id: \.self) { c in
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

                            CountryPicker(country: $country)
                            CityPicker(city: $city, country: country)

                            LuxuryTextField(title: "Address (optional)", text: $address)

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
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .stroke(Lx.gold.opacity(0.22), lineWidth: 1)
                                    )
                            }

                            HStack {
                                LuxuryTextField(title: "Latitude (optional)", text: $latitude, keyboard: .decimalPad)
                                LuxuryTextField(title: "Longitude (optional)", text: $longitude, keyboard: .decimalPad)
                            }

                            Stepper("Duration: \(durationMinutes) min", value: $durationMinutes, in: 30...480, step: 30)
                            Stepper("Max people: \(maxPeople)", value: $maxPeople, in: 1...30)
                            LuxuryTextField(title: "Price (€)", text: $price, keyboard: .decimalPad)
                            Toggle("Active", isOn: $active)

                            Divider().opacity(0.15)
                            Text("Fixed schedule sessions (optional)").font(.headline)
                            Text("Add one or more sessions so travelers can book a specific time.")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            DatePicker("Session", selection: $newSessionDate, displayedComponents: [.date, .hourAndMinute])
                                .datePickerStyle(.compact)

                            Button {
                                Haptics.light()
                                sessions.append(newSessionDate)
                                sessions = sessions.sorted()
                            } label: {
                                Text("Add session")
                            }
                            .buttonStyle(LuxurySecondaryButtonStyle())

                            if !sessions.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    ForEach(sessions.indices, id: \.self) { idx in
                                        HStack {
                                            Text(sessions[idx].formatted(date: .abbreviated, time: .shortened))
                                                .font(.subheadline.weight(.semibold))
                                            Spacer()
                                            Button {
                                                Haptics.light()
                                                sessions.remove(at: idx)
                                            } label: {
                                                Image(systemName: "trash")
                                                    .foregroundStyle(.secondary)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                }
                            }

                            Toggle("Repeat weekly", isOn: $repeatWeekly)
                            if repeatWeekly {
                                Stepper("Repeat for \(repeatWeeks) weeks", value: $repeatWeeks, in: 1...52)
                            }

                            Divider().opacity(0.15)
                            Text("Cancellation policy").font(.headline)
                            Stepper("Free cancellation: \(cancellationPolicy.freeCancelHours)h", value: $cancellationPolicy.freeCancelHours, in: 1...720)
                            Stepper("Refund after deadline: \(cancellationPolicy.refundPercentAfterDeadline)%", value: $cancellationPolicy.refundPercentAfterDeadline, in: 0...100)
                            Stepper("No-show refund: \(cancellationPolicy.noShowRefundPercent)%", value: $cancellationPolicy.noShowRefundPercent, in: 0...100)



                            Divider().opacity(0.15)
                            Text("Smart pricing & promos").font(.headline)

                            Stepper("Promo discount: \(promoPercent)%", value: $promoPercent, in: 0...80)
                            if promoPercent > 0 {
                                DatePicker("Promo start", selection: $promoStart, displayedComponents: [.date])
                                DatePicker("Promo end", selection: $promoEnd, displayedComponents: [.date])
                            }

                            Stepper("Last-minute window: \(lastMinuteHours)h", value: $lastMinuteHours, in: 1...168)
                            Stepper("Last-minute discount: \(lastMinutePercent)%", value: $lastMinutePercent, in: 0...80)

                            Stepper("Group min people: \(groupMinPeople)", value: $groupMinPeople, in: 2...30)
                            Stepper("Group discount: \(groupPercent)%", value: $groupPercent, in: 0...80)
                            // Sessions section above generates availability slots on publish.
                        }
                    }

                    if let message {
                        Text(message)
                            .foregroundStyle(.white.opacity(0.75))
                    }

                    Button {
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
        guard let hostEmail = appState.session.firebaseUser?.email else { return }
        guard let uid = appState.session.firebaseUser?.uid else { return }
        guard let coverImage else {
            message = "Please choose a cover image."
            return
        }

        isLoading = true
        message = nil

        do {
            let coverPath = "experiences/\(uid)/\(UUID().uuidString).jpg"
            let url = try await StorageService.shared.uploadJPEG(coverImage, path: coverPath)

            let sp = SmartPricingBuilder.build(
                promoPercent: promoPercent,
                promoStart: promoStart,
                promoEnd: promoEnd,
                lastMinuteHours: lastMinuteHours,
                lastMinutePercent: lastMinutePercent,
                groupMinPeople: groupMinPeople,
                groupPercent: groupPercent
            )

            // Optional geocoding: if an address was provided and no coordinates were entered.
            var lat = Double(latitude)
            var lon = Double(longitude)
            if (lat == nil || lon == nil), !address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                if let coord = try? await geocodeAddress("\(address), \(city), \(country)") {
                    lat = coord.latitude
                    lon = coord.longitude
                }
            }

            let exp = Experience(
                id: UUID().uuidString,
                hostEmail: hostEmail,
                title: title,
                description: description,
                city: city,
                country: country.isEmpty ? nil : country,
                address: address.isEmpty ? nil : address,
                coverPhotoURL: url.absoluteString,
                latitude: lat,
                longitude: lon,
                durationMinutes: durationMinutes,
                price: Double(price) ?? 0,
                maxPeople: maxPeople,
                category: category,
                difficulty: difficulty,
                physicalEffort: physicalEffort,
                authenticityScore: Int(authenticityScore),
                smartPricing: sp,
                cancellationPolicy: cancellationPolicy,
                active: active,
                createdAt: Date()
            )
            try await FirestoreService.shared.createExperience(exp)

            // Generate fixed schedule availability slots (if provided)
            if !sessions.isEmpty {
                var allDates: [Date] = sessions
                if repeatWeekly, repeatWeeks > 0 {
                    for base in sessions {
                        for w in 1...repeatWeeks {
                            if let d = Calendar.current.date(byAdding: .day, value: 7 * w, to: base) {
                                allDates.append(d)
                            }
                        }
                    }
                }

                for start in allDates.sorted() {
                    let end = start.addingTimeInterval(TimeInterval(durationMinutes * 60))
                    let slot = AvailabilitySlot(
                        id: UUID().uuidString,
                        email: hostEmail, // use guideId field as providerId for both guides and hosts
                        start: start,
                        end: end,
                        status: .open,
                        bookingId: nil,
                        createdAt: Date()
                    )
                    try? await FirestoreService.shared.createAvailability(slot)
                }
            }

            Haptics.success()
            message = "Experience published ✅"

            // Return to the Experiences view after publishing.
            await MainActor.run {
                dismiss()
            }

            title = ""
            description = ""
            city = ""
            country = ""
            address = ""
            price = "50"
            latitude = ""
            longitude = ""
            active = true
            self.coverImage = nil
            sessions = []
        } catch {
            message = error.localizedDescription
        }

        isLoading = false
    }

    private func geocodeAddress(_ address: String) async throws -> CLLocationCoordinate2D {
        try await withCheckedThrowingContinuation { cont in
            CLGeocoder().geocodeAddressString(address) { placemarks, error in
                if let error { cont.resume(throwing: error); return }
                if let c = placemarks?.first?.location?.coordinate {
                    cont.resume(returning: c)
                } else {
                    cont.resume(throwing: NSError(domain: "Geocode", code: 0, userInfo: [NSLocalizedDescriptionKey: "Address not found"]))
                }
            }
        }
    }
}
