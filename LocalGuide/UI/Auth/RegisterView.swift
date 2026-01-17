import SwiftUI

struct RegisterView: View {
    @EnvironmentObject var router: AuthRouter
    let role: UserRole

    @State private var email = ""
    @State private var password = ""
    @State private var fullName = ""
    @State private var dob = Date()
    @State private var hasDob = false

    @State private var country = ""
    @State private var city = ""

    @State private var preferredLanguage = "en"
    @State private var plan: SubscriptionPlan = .freeAds

    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(titleText)
                        .font(.title.bold())
                        .foregroundStyle(.white)

                    LuxuryTextField(title: "Full name", text: $fullName)
                    LuxuryTextField(title: "Email", text: $email, keyboard: .emailAddress)
                    LuxuryTextField(title: "Password (min 6)", text: $password, secure: true)

                    LuxuryCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Location").font(.headline)
                            CountryPicker(country: $country)
                            CityPicker(city: $city, country: country)
                            if !(CountryCityData.citiesByCountry[country]?.isEmpty ?? true) == false && !country.isEmpty {
                                Text("City list is a starter set — extend in CountryCityData.swift.")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    LuxuryCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Preferences").font(.headline)

                            Toggle("Add date of birth", isOn: $hasDob)
                            if hasDob {
                                DatePicker("Date of birth", selection: $dob, displayedComponents: [.date])
                                    .datePickerStyle(.compact)
                            }

                            Picker("Language", selection: $preferredLanguage) {
                                Text("English").tag("en")
                                Text("Romanian").tag("ro")
                                Text("French").tag("fr")
                                Text("Spanish").tag("es")
                                Text("Italian").tag("it")
                            }
                            .pickerStyle(.menu)

                            Picker("Plan", selection: $plan) {
                                Text("Free (with ads)").tag(SubscriptionPlan.freeAds)
                                Text("Premium").tag(SubscriptionPlan.premium)
                            }
                            .pickerStyle(.segmented)

                            Text("Premium unlocks discounts & exclusive experiences.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if let errorMessage { Text(errorMessage).foregroundStyle(.red) }

                    Button { Task { await register() } } label: {
                        if isLoading { ProgressView() } else { Text("Create account") }
                    }
                    .buttonStyle(LuxuryPrimaryButtonStyle())
                    .disabled(isLoading || email.isEmpty || password.count < 6 || fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || country.isEmpty || city.isEmpty)

                    if role == .guide {
                        Text("Guides are reviewed before going live.")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.6))
                    }

                    Spacer(minLength: 10)
                }
                .padding(18)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    private var titleText: String {
        switch role {
        case .guide: return "Create Guide Account"
        case .host: return "Create Host Account"
        case .traveler: return "Create Account"
        case .admin: return "Create Account"
        }
    }

    private func register() async {
        isLoading = true
        errorMessage = nil
        do {
            _ = try await AuthService.shared.register(
                email: email,
                password: password,
                role: role,
                fullName: fullName,
                dateOfBirth: hasDob ? dob : nil,
                country: country,
                city: city,
                preferredLanguageCode: preferredLanguage,
                subscriptionPlan: plan
            )

            // IMPORTANT: sign out and return to Login view as requested
            try? AuthService.shared.signOut()
            router.goToLogin()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
