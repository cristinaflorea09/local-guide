import SwiftUI

struct UserProfileEditView: View {
    @EnvironmentObject var appState: AppState

    @State private var fullName: String = ""
    @State private var dateOfBirth: Date = Date()
    @State private var country: String = ""
    @State private var city: String = ""

    @State private var isSaving = false
    @State private var message: String?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Edit profile")
                        .font(.largeTitle.bold())
                        .foregroundStyle(.white)
                        .padding(.top, 8)

                    LuxuryCard {
                        VStack(alignment: .leading, spacing: 12) {
                            LuxuryTextField(title: "Full name", text: $fullName)

                            DatePicker("Date of birth", selection: $dateOfBirth, displayedComponents: .date)
                                .datePickerStyle(.compact)
                                .foregroundStyle(.white)
                                .tint(Lx.gold)

                            Text("Location")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)

                            CountryPicker(country: $country)
                            CityPicker(city: $city, country: country)
                        }
                    }

                    if let message {
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.75))
                    }

                    Button {
                        Task { await save() }
                    } label: {
                        if isSaving {
                            ProgressView().tint(.black)
                        } else {
                            Text("Save")
                        }
                    }
                    .buttonStyle(LuxuryPrimaryButtonStyle())
                    .disabled(isSaving)

                    Spacer(minLength: 16)
                }
                .padding(18)
            }
        }
        .navigationTitle("Account")
        .navigationBarTitleDisplayMode(.inline)
        .task { loadFromSession() }
    }

    private func loadFromSession() {
        let u = appState.session.currentUser
        fullName = u?.fullName ?? ""
        country = u?.country ?? ""
        city = u?.city ?? ""

        // If you store DOB as a Timestamp or Date in AppUser later, set it here.
        // For now it defaults to today.
    }

    private func save() async {
        guard let uid = appState.session.firebaseUser?.uid else { return }

        isSaving = true
        message = nil

        do {
            // Store DOB as ISO string (simple + Firestore friendly)
            let dobISO = ISO8601DateFormatter().string(from: dateOfBirth)

            try await FirestoreService.shared.updateUser(uid: uid, fields: [
                "fullName": fullName.trimmingCharacters(in: .whitespacesAndNewlines),
                "country": country,
                "city": city,
                "dateOfBirth": dobISO
            ])

            await appState.session.refreshCurrentUserIfAvailable()
            message = "Saved ✅"
        } catch {
            message = error.localizedDescription
        }

        isSaving = false
    }
}
