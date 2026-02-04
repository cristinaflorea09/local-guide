import SwiftUI

struct CustomRequestFormView: View {
    let prefilledProviderEmail: String?

    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var providerEmail: String = ""
    @State private var titleText: String = ""
    @State private var details: String = ""
    @State private var country: String = ""
    @State private var city: String = ""
    @State private var hasPreferredDate: Bool = false
    @State private var preferredDate: Date = Date()
    @State private var budgetText: String = ""

    @State private var isSubmitting = false
    @State private var statusMessage: String?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Custom Request")
                        .font(.largeTitle.bold())
                        .foregroundStyle(.white)
                        .padding(.top, 8)

                    LuxuryCard {
                        VStack(alignment: .leading, spacing: 12) {
                            LuxuryTextField(title: "Provider email (guide/host)", text: $providerEmail)
                            LuxuryTextField(title: "Title (optional)", text: $titleText)

                            Text("Details")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            TextEditor(text: $details)
                                .frame(minHeight: 120)
                                .foregroundStyle(.white)
                                .padding(10)
                                .background(.white.opacity(0.06))
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                            Text("Location")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            CountryPicker(country: $country)
                            CityPicker(city: $city, country: country)

                            Toggle("Specify preferred date", isOn: $hasPreferredDate)
                                .tint(Lx.gold)
                            if hasPreferredDate {
                                DatePicker("Preferred date", selection: $preferredDate, displayedComponents: .date)
                                    .datePickerStyle(.compact)
                                    .foregroundStyle(.white)
                                    .tint(Lx.gold)
                            }

                            LuxuryTextField(title: "Budget (RON, optional)", text: $budgetText)
                        }
                    }

                    if let statusMessage {
                        Text(statusMessage)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.75))
                    }

                    Button {
                        Task { await submit() }
                    } label: {
                        if isSubmitting {
                            ProgressView().tint(.black)
                        } else {
                            Text("Send request")
                        }
                    }
                    .buttonStyle(LuxuryPrimaryButtonStyle())
                    .disabled(isSubmitting)

                    Spacer(minLength: 12)
                }
                .padding(18)
            }
        }
        .navigationTitle("Request")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if let e = prefilledProviderEmail, providerEmail.isEmpty {
                providerEmail = e
            }
        }
    }

    private func submit() async {
        // Validate session
        guard let requesterId = appState.session.currentUser?.id ?? appState.session.firebaseUser?.uid else {
            await MainActor.run { statusMessage = "Not signed in." }
            return
        }

        // Validate provider email
        let email = providerEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !email.isEmpty, email.contains("@") else {
            await MainActor.run { statusMessage = "Please enter a valid provider email." }
            return
        }

        isSubmitting = true
        statusMessage = nil

        do {
            // Parse budget as Double if provided
            let budget = Double(budgetText.replacingOccurrences(of: ",", with: "."))

            let req = CustomRequest(
                id: UUID().uuidString,
                requesterId: requesterId,
                providerEmail: email,
                title: titleText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : titleText.trimmingCharacters(in: .whitespacesAndNewlines),
                message: details.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : details.trimmingCharacters(in: .whitespacesAndNewlines),
                city: city.isEmpty ? nil : city,
                country: country.isEmpty ? nil : country,
                preferredDate: hasPreferredDate ? preferredDate : nil,
                budget: budget,
                listingType: nil,
                listingId: nil,
                status: .pending,
                createdAt: Date(),
                updatedAt: nil
            )

            try await FirestoreService.shared.createCustomRequest(req)
            Haptics.success()
            await MainActor.run {
                statusMessage = "Request sent ✅"
                dismiss()
            }
        } catch {
            await MainActor.run { statusMessage = error.localizedDescription }
        }

        isSubmitting = false
    }
}
