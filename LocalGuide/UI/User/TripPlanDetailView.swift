import SwiftUI

struct TripPlanDetailView: View {
    let tripPlan: TripPlan

    @State private var recommendedTours: [Tour] = []
    @State private var recommendedExperiences: [Experience] = []
    @State private var recsLoaded = false

    // Presented when tapping an itinerary item that references a listing.
    @State private var selectedTour: Tour?
    @State private var selectedExperience: Experience?

    @Environment(\.dismiss) private var dismiss

    private var planDict: [String: Any] {
        tripPlan.plan.mapValues { decodeAny($0) }
    }

    private func decodeAny(_ v: AnyCodable) -> Any {
        switch v.value {
        case let a as [AnyCodable]:
            return a.map { decodeAny($0) }
        case let d as [String: AnyCodable]:
            return d.mapValues { decodeAny($0) }
        default:
            return v.value
        }
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    LuxuryCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Trip plan")
                                .font(.title3.bold())
                                .foregroundStyle(.white)

                            if let title = planDict["title"] as? String, !title.isEmpty {
                                Text(title)
                                    .font(.headline)
                                    .foregroundStyle(Lx.gold)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }

                            Text("\(tripPlan.city), \(tripPlan.country)")
                                .foregroundStyle(.white.opacity(0.85))

                            Text("\(tripPlan.startDateISO) → \(tripPlan.endDateISO)")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.70))

                            if !tripPlan.interests.isEmpty {
                                Text("Interests: \(tripPlan.interests.joined(separator: ", "))")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.70))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }

                            if let createdAt = tripPlan.createdAt {
                                Text("Created: \(createdAt.formatted(date: .abbreviated, time: .shortened))")
                                    .font(.caption2)
                                    .foregroundStyle(.white.opacity(0.60))
                            }
                        }
                    }

                    if !recommendedTours.isEmpty || !recommendedExperiences.isEmpty {
                        LuxuryCard {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Recommended in the app")
                                    .font(.headline)
                                    .foregroundStyle(.white)

                                if !recommendedTours.isEmpty {
                                    Text("Tours")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                    ForEach(recommendedTours) { t in
                                        NavigationLink { TourDetailsView(tour: t) } label: {
                                            HStack {
                                                Text(t.title)
                                                    .foregroundStyle(.white)
                                                    .lineLimit(1)
                                                Spacer()
                                                Text("€\(t.price, specifier: "%.0f")")
                                                    .font(.caption)
                                                    .foregroundStyle(.white.opacity(0.7))
                                            }
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }

                                if !recommendedExperiences.isEmpty {
                                    if !recommendedTours.isEmpty { Divider().opacity(0.15) }
                                    Text("Experiences")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                    ForEach(recommendedExperiences) { e in
                                        NavigationLink { ExperienceDetailsView(experience: e) } label: {
                                            HStack {
                                                Text(e.title)
                                                    .foregroundStyle(.white)
                                                    .lineLimit(1)
                                                Spacer()
                                                Text("€\(e.price, specifier: "%.0f")")
                                                    .font(.caption)
                                                    .foregroundStyle(.white.opacity(0.7))
                                            }
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                    }

                    TripPlanJSONResultsView(plan: planDict) { listingType, listingId in
                        Task { await openListing(listingType: listingType, listingId: listingId) }
                    }

                    Spacer(minLength: 12)
                }
                .padding(18)
            }
        }
        .navigationTitle("Trip plan")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadRecommendationsIfNeeded() }
        .fullScreenCover(item: $selectedTour) { t in
            DismissableSheet {
                TourDetailsView(tour: t)
            }
        }
        .fullScreenCover(item: $selectedExperience) { e in
            DismissableSheet {
                ExperienceDetailsView(experience: e)
            }
        }
    }

    private func openListing(listingType: String, listingId: String) async {
        let type = listingType.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if type == "tour" {
            if let t = try? await FirestoreService.shared.getTour(tourId: listingId) {
                selectedTour = t
            }
        } else if type == "experience" {
            if let e = try? await FirestoreService.shared.getExperience(experienceId: listingId) {
                selectedExperience = e
            }
        }
    }

    private func loadRecommendationsIfNeeded() async {
        guard !recsLoaded else { return }
        recsLoaded = true
        do {
            if let ids = tripPlan.recommendedTourIds {
                var loaded: [Tour] = []
                for id in ids.prefix(10) {
                    if let t = try? await FirestoreService.shared.getTour(tourId: id) {
                        loaded.append(t)
                    }
                }
                recommendedTours = loaded
            }
            if let ids = tripPlan.recommendedExperienceIds {
                var loaded: [Experience] = []
                for id in ids.prefix(10) {
                    if let e = try? await FirestoreService.shared.getExperience(experienceId: id) {
                        loaded.append(e)
                    }
                }
                recommendedExperiences = loaded
            }
        }
    }
}

/// Wraps a view in a NavigationStack with a close button for fullScreenCover presentations.
private struct DismissableSheet<Content: View>: View {
    @Environment(\.dismiss) private var dismiss
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        NavigationStack {
            content
                // Force a navigation bar context so the close button is always visible.
                .navigationTitle("")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                        }
                    }
                }
        }
    }
}

private struct TripPlanJSONResultsView: View {
    let plan: [String: Any]
    var onSelectListing: (_ listingType: String, _ listingId: String) -> Void

    var body: some View {
        LuxuryCard {
            VStack(alignment: .leading, spacing: 10) {
                Text(plan["title"] as? String ?? "Your plan")
                    .font(.title3.bold())
                    .foregroundStyle(.white)

                if let summary = plan["summary"] as? String {
                    Text(summary)
                        .foregroundStyle(.white.opacity(0.8))
                }

                if let days = plan["days"] as? [[String: Any]] {
                    ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(day["dateISO"] as? String ?? "")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Lx.gold)

                            if let theme = day["theme"] as? String {
                                Text(theme)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            if let items = day["items"] as? [[String: Any]] {
                                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                                    itineraryItemView(item)
                                }
                            }
                        }
                        Divider().opacity(0.12)
                    }
                }

                if let notes = plan["budgetNotes"] as? String, !notes.isEmpty {
                    Text(notes)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.75))
                }
            }
        }
    }

    @ViewBuilder
    private func itineraryItemView(_ item: [String: Any]) -> some View {
        let time = (item["time"] as? String) ?? ""
        let title = (item["title"] as? String) ?? ""
        let desc = (item["description"] as? String) ?? ""
        let listingType = (item["listingType"] as? String) ?? ""
        let listingId = (item["listingId"] as? String) ?? ""

        // If the itinerary item references an in-app listing, show it as a tappable card.
        if !listingType.isEmpty && !listingId.isEmpty {
            Button {
                onSelectListing(listingType, listingId)
            } label: {
                ItineraryListingCard(
                    listingType: listingType,
                    listingId: listingId,
                    time: time,
                    title: title,
                    descriptionText: desc
                )
            }
            .buttonStyle(.plain)
            .padding(.vertical, 4)
        } else {
            VStack(alignment: .leading, spacing: 2) {
                Text(time.isEmpty ? title : "\(time) • \(title)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                if !desc.isEmpty {
                    Text(desc)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.75))
                }
            }
            .padding(.vertical, 4)
        }
    }
}

private struct ItineraryListingCard: View {
    let listingType: String
    let listingId: String
    let time: String
    let title: String
    let descriptionText: String

    @State private var tour: Tour?
    @State private var experience: Experience?
    @State private var didLoad = false

    private var isTour: Bool {
        listingType.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "tour"
    }

    private var displayTitle: String {
        if isTour { return tour?.title ?? title }
        return experience?.title ?? title
    }

    private var imageURL: URL? {
        if isTour {
            if let s = tour?.coverPhotoURL { return URL(string: s) }
        } else {
            if let s = experience?.coverPhotoURL { return URL(string: s) }
        }
        return nil
    }

    private var priceText: String? {
        let p: Double?
        if isTour { p = tour?.price }
        else { p = experience?.price }
        guard let p else { return nil }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "EUR"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: p))
    }

    private var ratingValue: Double? {
        if isTour { return tour?.ratingAvg }
        return experience?.ratingAvg
    }

    private var ratingCount: Int? {
        if isTour { return tour?.ratingCount }
        return experience?.ratingCount
    }

    var body: some View {
        LuxuryCard {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(.white.opacity(0.06))
                    if let imageURL {
                        AsyncImage(url: imageURL) { phase in
                            switch phase {
                            case .empty:
                                ProgressView().tint(Lx.gold)
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFill()
                            default:
                                Image(systemName: isTour ? "map" : "sparkles")
                                    .foregroundStyle(.white.opacity(0.7))
                            }
                        }
                    } else {
                        Image(systemName: isTour ? "map" : "sparkles")
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
                .frame(width: 78, height: 78)
                .clipShape(RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 6) {
                    Text(time.isEmpty ? displayTitle : "\(time) • \(displayTitle)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .lineLimit(2)

                    if !descriptionText.isEmpty {
                        Text(descriptionText)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.75))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .lineLimit(3)
                    }

                    HStack(spacing: 10) {
                        Text(isTour ? "Tour" : "Experience")
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Lx.gold.opacity(0.18))
                            .clipShape(Capsule())

                        if let priceText {
                            Text(priceText)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.85))
                        }

                        if let ratingValue, let ratingCount, ratingCount > 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "star.fill")
                                    .font(.caption2)
                                    .foregroundStyle(Lx.gold)
                                Text(String(format: "%.1f", ratingValue))
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.85))
                                Text("(\(ratingCount))")
                                    .font(.caption2)
                                    .foregroundStyle(.white.opacity(0.65))
                            }
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.65))
                    }
                }
            }
        }
        .task {
            guard !didLoad else { return }
            didLoad = true
            let type = listingType.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if type == "tour" {
                tour = try? await FirestoreService.shared.getTour(tourId: listingId)
            } else if type == "experience" {
                experience = try? await FirestoreService.shared.getExperience(experienceId: listingId)
            }
        }
    }
}

