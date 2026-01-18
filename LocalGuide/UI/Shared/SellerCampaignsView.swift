import SwiftUI
import FirebaseFirestore

/// Lets a Guide or Host manage promo campaigns / smart pricing for listings.
struct SellerCampaignsView: View {
    @EnvironmentObject var appState: AppState
    @State private var isLoading = false
    @State private var tours: [Tour] = []
    @State private var experiences: [Experience] = []

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Campaigns")
                            .font(.largeTitle.bold())
                            .foregroundStyle(.white)

                        if isLoading { ProgressView().tint(Lx.gold) }

                        if appState.session.currentUser?.role == .guide {
                            ForEach(tours) { t in
                                ListingCampaignCard(title: t.title, smartPricing: t.smartPricing) { updated in
                                    Task {
                                        try? await FirestoreService.shared.updateTour(tourId: t.id, fields: ["smartPricing": try Firestore.Encoder().encode(updated)])
                                        await load()
                                    }
                                }
                            }
                        } else {
                            ForEach(experiences) { e in
                                ListingCampaignCard(title: e.title, smartPricing: e.smartPricing) { updated in
                                    Task {
                                        try? await FirestoreService.shared.updateExperience(experienceId: e.id, fields: ["smartPricing": try Firestore.Encoder().encode(updated)])
                                        await load()
                                    }
                                }
                            }
                        }
                    }
                    .padding(18)
                }
            }
            .task { await load() }
        }
    }

    private func load() async {
        guard let uid = appState.session.firebaseUser?.uid else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            if appState.session.currentUser?.role == .guide {
                tours = try await FirestoreService.shared.getToursForGuide(guideId: uid)
            } else {
                experiences = try await FirestoreService.shared.getExperiencesForHost(hostId: uid)
            }
        } catch { }
    }
}

private struct ListingCampaignCard: View {
    let title: String
    let smartPricing: SmartPricing?
    var onSave: (SmartPricing) -> Void

    @State private var promoPercent: Int = 0
    @State private var promoStart: Date = Date()
    @State private var promoEnd: Date = Date().addingTimeInterval(7*24*3600)
    @State private var lastMinuteHours: Int = 24
    @State private var lastMinutePercent: Int = 0
    @State private var groupMinPeople: Int = 4
    @State private var groupPercent: Int = 0

    var body: some View {
        LuxuryCard {
            VStack(alignment: .leading, spacing: 10) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)

                Stepper("Promo discount: \(promoPercent)%", value: $promoPercent, in: 0...80)
                if promoPercent > 0 {
                    DatePicker("Promo start", selection: $promoStart, displayedComponents: [.date])
                    DatePicker("Promo end", selection: $promoEnd, displayedComponents: [.date])
                }

                Stepper("Last-minute window: \(lastMinuteHours)h", value: $lastMinuteHours, in: 1...168)
                Stepper("Last-minute discount: \(lastMinutePercent)%", value: $lastMinutePercent, in: 0...80)

                Stepper("Group min people: \(groupMinPeople)", value: $groupMinPeople, in: 2...30)
                Stepper("Group discount: \(groupPercent)%", value: $groupPercent, in: 0...80)

                Button("Save") {
                    var updated = SmartPricing()
                    if promoPercent > 0 {
                        let iso = ISO8601DateFormatter()
                        let campaign = PromoCampaign(
                            id: String(promoPercent),
                            name: iso.string(from: promoStart),
                            startISO: iso.string(from: promoStart),
                            endISO: iso.string(from: promoEnd),
                            percentOff: promoPercent
                        )
                        updated.promoCampaigns = [campaign]
                    } else {
                        updated.promoCampaigns = []
                    }
                    onSave(updated)
                }
                .buttonStyle(LuxuryPrimaryButtonStyle())
            }
        }
        .onAppear {
            if let firstCampaign = smartPricing?.promoCampaigns?.first {
                promoPercent = firstCampaign.percentOff
                let isoFormatter = ISO8601DateFormatter()
                if let startDate = isoFormatter.date(from: firstCampaign.startISO) {
                    promoStart = startDate
                }
                if let endDate = isoFormatter.date(from: firstCampaign.endISO) {
                    promoEnd = endDate
                }
            } else {
                promoPercent = 0
                // keep current defaults for promoStart and promoEnd when no campaign exists
            }
            // Initialize from existing smartPricing if compatible fields are available; otherwise keep defaults
        }
    }
}

