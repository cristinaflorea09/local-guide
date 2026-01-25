import SwiftUI
import FirebaseFirestore

/// Lets a Guide or Host manage discount promo campaigns / smart pricing for their listings.
///
/// UX:
/// - Intro card + "Create campaign" button
/// - Clickable list of listings
/// - Tapping opens a dedicated edit screen
struct SellerCampaignsView: View {
    @EnvironmentObject var appState: AppState
    @State private var isLoading = false
    @State private var tours: [Tour] = []
    @State private var experiences: [Experience] = []

    private var isGuide: Bool {
        appState.session.currentUser?.role == .guide
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Campaigns")
                        .font(.largeTitle.bold())
                        .foregroundStyle(.white)

                    LuxuryCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Create a discount campaign")
                                .font(.title3.bold())
                                .foregroundStyle(.white)
                            Text("Boost conversions by offering time-based promotions, last-minute discounts, or group deals.")
                                .foregroundStyle(.white.opacity(0.75))
                            NavigationLink {
                                CampaignListingPickerView(
                                    isGuide: isGuide,
                                    tours: tours,
                                    experiences: experiences
                                )
                            } label: {
                                HStack(spacing: 8) {
                                    Text("Create campaign")
                                    Image(systemName: "plus")
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(LuxuryPrimaryButtonStyle())
                        }
                    }

                    if isLoading {
                        ProgressView().tint(Lx.gold)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Your listings")
                            .font(.headline)
                            .foregroundStyle(.white)

                        if listingsEmpty {
                            LuxuryCard {
                                Text(isGuide ? "No tours yet." : "No experiences yet.")
                                    .foregroundStyle(.white.opacity(0.8))
                            }
                        } else {
                            ForEach(listingRows) { row in
                                NavigationLink {
                                    CampaignEditorView(
                                        title: row.title,
                                        smartPricing: row.smartPricing,
                                        onSave: { updated in
                                            Task {
                                                await save(row: row, smartPricing: updated)
                                            }
                                        }
                                    )
                                } label: {
                                    LuxuryCard {
                                        HStack {
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(row.title)
                                                    .font(.headline)
                                                    .foregroundStyle(.white)
                                                Text(row.summary)
                                                    .font(.caption)
                                                    .foregroundStyle(.white.opacity(0.75))
                                            }
                                            Spacer()
                                            Image(systemName: "chevron.right")
                                                .foregroundStyle(.white.opacity(0.6))
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(18)
            }
        }
        .navigationTitle("Campaigns")
        .task { await load() }
        .refreshable { await load() }
    }

    private var listingsEmpty: Bool {
        isGuide ? tours.isEmpty : experiences.isEmpty
    }

    private struct ListingRow: Identifiable {
        let id: String
        let title: String
        let smartPricing: SmartPricing?

        var summary: String {
            if let first = smartPricing?.promoCampaigns?.first, first.percentOff > 0 {
                return "Promo: \(first.percentOff)% off"
            }
            return "No active campaign"
        }
    }

    private var listingRows: [ListingRow] {
        if isGuide {
            return tours.map { .init(id: $0.id, title: $0.title, smartPricing: $0.smartPricing) }
        }
        return experiences.map { .init(id: $0.id, title: $0.title, smartPricing: $0.smartPricing) }
    }

    private func load() async {
        guard let email = appState.session.firebaseUser?.email else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            if isGuide {
                tours = try await FirestoreService.shared.getToursForGuide(guideEmail: email)
            } else {
                experiences = try await FirestoreService.shared.getExperiencesForHost(hostEmail: email)
            }
        } catch {
            tours = []
            experiences = []
        }
    }

    private func save(row: ListingRow, smartPricing: SmartPricing) async {
        do {
            let enc = try Firestore.Encoder().encode(smartPricing)
            if isGuide {
                try await FirestoreService.shared.updateTour(tourId: row.id, fields: ["smartPricing": enc])
            } else {
                try await FirestoreService.shared.updateExperience(experienceId: row.id, fields: ["smartPricing": enc])
            }
            await load()
        } catch {
            // ignore: surfaced by UI elsewhere if needed
        }
    }
}

/// Simple picker used by the "Create campaign" CTA.
private struct CampaignListingPickerView: View {
    let isGuide: Bool
    let tours: [Tour]
    let experiences: [Experience]

    var body: some View {
        List {
            if isGuide {
                ForEach(tours) { t in
                    NavigationLink {
                        CampaignEditorView(title: t.title, smartPricing: t.smartPricing) { updated in
                            Task {
                                let enc = try? Firestore.Encoder().encode(updated)
                                if let enc {
                                    try? await FirestoreService.shared.updateTour(tourId: t.id, fields: ["smartPricing": enc])
                                }
                            }
                        }
                    } label: {
                        Text(t.title)
                    }
                }
            } else {
                ForEach(experiences) { e in
                    NavigationLink {
                        CampaignEditorView(title: e.title, smartPricing: e.smartPricing) { updated in
                            Task {
                                let enc = try? Firestore.Encoder().encode(updated)
                                if let enc {
                                    try? await FirestoreService.shared.updateExperience(experienceId: e.id, fields: ["smartPricing": enc])
                                }
                            }
                        }
                    } label: {
                        Text(e.title)
                    }
                }
            }
        }
        .navigationTitle("Select listing")
    }
}

/// Dedicated editor screen for a single listing's smart pricing / campaign rules.
private struct CampaignEditorView: View {
    let title: String
    let smartPricing: SmartPricing?
    var onSave: (SmartPricing) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var promoPercent: Int = 0
    @State private var promoStart: Date = Date()
    @State private var promoEnd: Date = Date().addingTimeInterval(7 * 24 * 3600)
    @State private var lastMinuteHours: Int = 24
    @State private var lastMinutePercent: Int = 0
    @State private var groupMinPeople: Int = 4
    @State private var groupPercent: Int = 0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text(title)
                        .font(.title2.bold())
                        .foregroundStyle(.white)

                    LuxuryCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Stepper("Promo discount: \(promoPercent)%", value: $promoPercent, in: 0...80)
                            if promoPercent > 0 {
                                DatePicker("Promo start", selection: $promoStart, displayedComponents: [.date])
                                DatePicker("Promo end", selection: $promoEnd, displayedComponents: [.date])
                            }

                            Stepper("Last-minute window: \(lastMinuteHours)h", value: $lastMinuteHours, in: 1...168)
                            Stepper("Last-minute discount: \(lastMinutePercent)%", value: $lastMinutePercent, in: 0...80)

                            Stepper("Group min people: \(groupMinPeople)", value: $groupMinPeople, in: 2...30)
                            Stepper("Group discount: \(groupPercent)%", value: $groupPercent, in: 0...80)
                        }
                    }

                    Button("Save") {
                        onSave(buildSmartPricing())
                        dismiss() // return to campaigns view
                    }
                    .buttonStyle(LuxuryPrimaryButtonStyle())

                    Spacer(minLength: 14)
                }
                .padding(18)
            }
        }
        .navigationTitle("Edit campaign")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { hydrate() }
    }

    private func hydrate() {
        if let first = smartPricing?.promoCampaigns?.first {
            promoPercent = first.percentOff
            let iso = ISO8601DateFormatter()
            if let s = iso.date(from: first.startISO) { promoStart = s }
            if let e = iso.date(from: first.endISO) { promoEnd = e }
        }
    }

    private func buildSmartPricing() -> SmartPricing {
        var updated = SmartPricing()
        if promoPercent > 0 {
            let iso = ISO8601DateFormatter()
            let campaign = PromoCampaign(
                id: UUID().uuidString,
                name: "Promo \(promoPercent)%",
                startISO: iso.string(from: promoStart),
                endISO: iso.string(from: promoEnd),
                percentOff: promoPercent
            )
            updated.promoCampaigns = [campaign]
        } else {
            updated.promoCampaigns = []
        }
        // Note: last-minute/group are not persisted yet in your SmartPricing model.
        // Keeping fields in UI for future expansion.
        _ = lastMinuteHours
        _ = lastMinutePercent
        _ = groupMinPeople
        _ = groupPercent
        return updated
    }
}

