import SwiftUI
import FirebaseAuth

struct RegisterView: View {
     var appState: AppState
    @EnvironmentObject var router: AuthRouter
    let role: UserRole

    @State private var email = ""
    @State private var password = ""
    @State private var fullName = ""
    @State private var dob = Date()
    @State private var hasDob = false

    @State private var country = ""
    @State private var city = ""

    // The app language is controlled globally via AppSettings (no Save needed).
    @State private var plan: SubscriptionPlan = .freeAds

    // Business (Guides/Hosts)
    @State private var businessType = "PFA"
    @State private var businessName = ""
    @State private var businessRegNo = ""
    @State private var businessTaxId = ""
    @State private var businessAddress = ""
    @State private var businessCertificate: PickedDocument?
    @State private var showCertificatePicker = false

    // Provider contract
    @State private var acceptedIntermediary = false
    @State private var showIntermediary = false
    @State private var showPrivacy = false
    @State private var showCancellation = false
    @State private var showSrlGuide = false

    @State private var acceptedTerms = false
    @State private var showTerms = false

    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack(alignment: .topLeading) {
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
                        }
                    }

                    if role == .guide || role == .host {
                        LuxuryCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Business (SRL/PFA)").font(.headline)
                                Picker("Type", selection: $businessType) {
                                    Text("PFA").tag("PFA")
                                    Text("SRL").tag("SRL")
                                }
                                .pickerStyle(.segmented)

                                LuxuryTextField(title: "Business name", text: $businessName)
                                LuxuryTextField(title: "Registration no. (ONRC)", text: $businessRegNo)
                                LuxuryTextField(title: "Tax ID (CUI/CIF)", text: $businessTaxId)
                                LuxuryTextField(title: "Business address", text: $businessAddress)

                                Button {
                                    showCertificatePicker = true
                                } label: {
                                    HStack {
                                        Text(businessCertificate == nil ? "Upload registration certificate" : "Certificate: \(businessCertificate!.fileName)")
                                        Spacer()
                                        Image(systemName: "doc.badge.plus")
                                    }
                                }
                                .buttonStyle(LuxurySecondaryButtonStyle())

                                Button {
                                    showSrlGuide = true
                                } label: {
                                    Text("How to open a SRL/PFA in Romania")
                                }
                                .buttonStyle(LuxurySecondaryButtonStyle())

                                Divider().opacity(0.15)
                                Toggle(isOn: $acceptedIntermediary) {
                                    Text("I accept the Intermediary Agreement")
                                }
                                Button {
                                    showIntermediary = true
                                } label: {
                                    Text("Read Intermediary Agreement")
                                }
                                .buttonStyle(LuxurySecondaryButtonStyle())
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



                            Picker("Plan", selection: $plan) {
                                Text("Free (with ads)").tag(SubscriptionPlan.freeAds)
                                Text("Premium").tag(SubscriptionPlan.premium)
                            }
                            .pickerStyle(.segmented)
                        }
                    }

                    LuxuryCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Toggle(isOn: $acceptedTerms) {
                                Text("I accept the Terms & Conditions")
                                    .foregroundStyle(.primary)
                            }
                            Button {
                                showTerms = true
                            } label: {
                                Text("Read Terms & Conditions")
                            }
                            .buttonStyle(LuxurySecondaryButtonStyle())

                            Button {
                                showPrivacy = true
                            } label: {
                                Text("Read Privacy Policy")
                            }
                            .buttonStyle(LuxurySecondaryButtonStyle())

                            Button {
                                showCancellation = true
                            } label: {
                                Text("Read Cancellation Policy")
                            }
                            .buttonStyle(LuxurySecondaryButtonStyle())

                            Text(TermsText.current)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if let errorMessage { Text(errorMessage).foregroundStyle(.red) }

                    Button { Task { await register() } } label: {
                        if isLoading { ProgressView() } else { Text("Create account") }
                    }
                    .buttonStyle(LuxuryPrimaryButtonStyle())
                    .disabled(isLoading || !acceptedTerms || !providerRequirementsMet || email.isEmpty || password.count < 6 || fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || country.isEmpty || city.isEmpty)

                    Text(role == .admin
                         ? "Admin accounts do not require email verification."
                         : "After creation we send a verification email. Please verify, then login.")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))

                    Spacer(minLength: 10)
                }
                .padding(18)
            }

            LanguageSwitcherOverlay()
                .padding(.leading, 12)
                .padding(.top, 10)
        }
        .sheet(isPresented: $showTerms) {
            legalSheet(.terms, title: "Terms & Conditions")
        }
        .sheet(isPresented: $showIntermediary) {
            let t = LegalPDF.intermediaryType(for: businessType)
            legalSheet(t, title: businessType.uppercased().contains("SRL") ? "Intermediary Contract (SRL)" : "Intermediary Contract (PFA)")
        }
        .sheet(isPresented: $showPrivacy) {
            legalSheet(.privacy, title: "Privacy Policy")
        }
        .sheet(isPresented: $showCancellation) {
            legalSheet(.cancellation, title: "Cancellation Policy")
        }
        .sheet(isPresented: $showSrlGuide) {
            TermsView(markdown: LegalDocuments.markdown(.srlPfaGuide, languageCode: appState.settings.languageCode))
        }
        .sheet(isPresented: $showCertificatePicker) {
            DocumentPicker(onPick: { doc in
                businessCertificate = doc
                showCertificatePicker = false
            }, onCancel: {
                showCertificatePicker = false
            })
        }
        .navigationBarTitleDisplayMode(.inline)
    }


    @ViewBuilder
    private func legalSheet(_ type: LegalPDFType, title: String) -> some View {
        if let url = LegalPDF.url(for: type, languageCode: appState.settings.languageCode) {
            NavigationStack {
                PDFDocumentView(title: title, url: url)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close") {
                                // Sheets are dismissed by the system; button is purely a visual affordance.
                            }
                        }
                    }
            }
        } else {
            NavigationStack {
                VStack(spacing: 12) {
                    Text(title).font(.headline)
                    Text("Missing PDF in bundle. Add it to Resources/LegalPDFs/<lang>/").font(.footnote).foregroundStyle(.secondary)
                }.padding()
            }
        }
    }
    private var titleText: String {
        switch role {
        case .guide: return "Create Guide Account"
        case .host: return "Create Host Account"
        case .traveler: return "Create Account"
        case .admin: return "Create Account"
        }
    }

    private var providerRequirementsMet: Bool {
        if !(role == .guide || role == .host) { return true }
        let base = !businessName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !businessRegNo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !businessTaxId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !businessAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && businessCertificate != nil
            && acceptedIntermediary
        return base
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
                preferredLanguageCode: appState.settings.languageCode,
                subscriptionPlan: plan,
                acceptedTermsVersion: Legal.termsVersion
            )
            // If provider, upload business certificate and store business + contract acceptance.
            if (role == .guide || role == .host), let uid = Auth.auth().currentUser?.uid {
                var patch: [String: Any] = [
                    "businessType": businessType,
                    "businessName": businessName,
                    "businessRegistrationNumber": businessRegNo,
                    "businessTaxId": businessTaxId,
                    "businessAddress": businessAddress,
                    "acceptedIntermediaryVersion": Legal.intermediaryVersion,
                    "acceptedIntermediaryAt": Date()
                ]
                if let doc = businessCertificate {
                    let url = try await StorageService.shared.uploadBusinessCertificate(uid: uid, data: doc.data, fileName: doc.fileName, contentType: doc.contentType)
                    patch["businessCertificateURL"] = url
                }
                try await FirestoreService.shared.updateUser(uid: uid, fields: patch)
            }
            // Stay signed in so the app can show VerifyEmailView.
            // After the user verifies, the VerifyEmailView will sign the user out
            // and route them back to Login.
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
