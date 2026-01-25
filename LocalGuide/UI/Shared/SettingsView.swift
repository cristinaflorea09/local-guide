import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        NavigationStack {
            Form(content: {
                Section(header: Text("Language"), content: {
                    Picker("App language", selection: Binding(
                        get: { appState.settings.languageCode },
                        set: { appState.settings.setLanguage($0) }
                    )) {
                        Text("English").tag("en")
                        Text("Română").tag("ro")
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: appState.settings.languageCode) { newCode in
                        // Persist without requiring an explicit save.
                        guard let uid = appState.session.currentUser?.id else { return }
                        Task {
                            try? await FirestoreService.shared.updateUser(uid: uid, fields: [
                                "preferredLanguageCode": newCode
                            ])
                        }
                    }

                    Text("Changes apply immediately.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                })

                Section(header: Text("Legal"), content: {
                    LegalPDFNavLink(title: "Terms & Conditions", type: .terms)
                    LegalPDFNavLink(title: "Privacy Policy", type: .privacy)
                    LegalPDFNavLink(title: "Cancellation Policy", type: .cancellation)
                    LegalPDFNavLink(title: "Annex", type: .annex)

                    // Seller-only documents. Travelers should not see these.
                    if appState.session.currentUser?.role == .guide || appState.session.currentUser?.role == .host {
                        LegalPDFNavLink(title: "Data Processing Addendum (DPA)", type: .dpa)

                        // Intermediary contracts: show only the relevant one based on businessType.
                        let bt = (appState.session.currentUser?.businessType ?? "").uppercased()
                        if bt == "PFA" {
                            LegalPDFNavLink(title: "Intermediary Contract (PFA)", type: .intermediaryPFA)
                        } else if bt == "SRL" {
                            LegalPDFNavLink(title: "Intermediary Contract (SRL)", type: .intermediarySRL)
                        } else {
                            // If businessType is missing, show both so sellers can still access.
                            LegalPDFNavLink(title: "Intermediary Contract (PFA)", type: .intermediaryPFA)
                            LegalPDFNavLink(title: "Intermediary Contract (SRL)", type: .intermediarySRL)
                        }
                    }
                })

                if appState.session.currentUser?.role == .guide || appState.session.currentUser?.role == .host {
                    Section(header: Text("Seller"), content: {
                        NavigationLink("Stripe payouts") { StripePayoutsView() }
                        NavigationLink("SRL/PFA guide") {
                            TermsView(markdown: LegalDocuments.markdown(.srlPfaGuide, languageCode: appState.settings.languageCode))
                        }
                    })
                }
            })
            .navigationTitle("Settings")
        }
        .onChange(of: appState.settings.languageCode) { newCode in
            guard let uid = appState.session.firebaseUser?.uid else { return }
            Task {
                try? await FirestoreService.shared.updateUser(uid: uid, fields: [
                    "preferredLanguageCode": newCode
                ])
            }
        }
    }

    private func legalURL(_ type: LegalPDFType) -> URL? {
        LegalPDF.url(for: type, languageCode: appState.settings.languageCode)
    }

    @ViewBuilder
    private func LegalPDFNavLink(title: String, type: LegalPDFType) -> some View {
        if let url = legalURL(type) {
            NavigationLink(title) {
                PDFDocumentView(title: title, url: url)
            }
        } else {
            HStack {
                Text(title)
                Spacer()
                Text("Missing PDF")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

/// Dedicated payouts screen.
struct StripePayoutsView: View {
    @Environment(\.openURL) private var openURL
    @EnvironmentObject var appState: AppState
    @State private var toast: String?
    @State private var isLoading = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 14) {
                LuxuryCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Payouts")
                            .font(.headline)
                        Text("Connect Stripe Express to receive payouts after tours/experiences complete.")
                            .foregroundStyle(.secondary)

                        if (appState.session.currentUser?.stripeAccountId ?? "").isEmpty {
                            Button {
                                Task {
                                    isLoading = true
                                    defer { isLoading = false }
                                    do {
                                        let url = try await StripeConnectService.shared.createExpressOnboardingLink()
                                        openURL(url)
                                    } catch {
                                        toast = error.localizedDescription
                                    }
                                }
                            } label: {
                                if isLoading {
                                    HStack(spacing: 8) { ProgressView().tint(.white); Text("Opening…") }
                                } else {
                                    Text("Connect Stripe")
                                }
                            }
                            .buttonStyle(LuxuryPrimaryButtonStyle())
                        } else {
                            HStack {
                                Image(systemName: "checkmark.seal.fill").foregroundStyle(Lx.gold)
                                Text("Stripe connected")
                                    .foregroundStyle(.white)
                            }
                        }
                    }
                }

                Spacer()
            }
            .padding(18)
        }
        .navigationTitle("Stripe payouts")
        .navigationBarTitleDisplayMode(.inline)
        .alert("", isPresented: Binding(get: { toast != nil }, set: { if !$0 { toast = nil } })) {
            Button("OK", role: .cancel) { toast = nil }
        } message: {
            Text(toast ?? "")
        }
    }
}
