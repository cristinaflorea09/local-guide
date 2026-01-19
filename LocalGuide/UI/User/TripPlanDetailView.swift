import SwiftUI

struct TripPlanDetailView: View {
    let tripPlan: TripPlan

    @State private var recommendedTours: [Tour] = []
    @State private var recommendedExperiences: [Experience] = []
    @State private var recsLoaded = false

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

                    TripPlanJSONResultsView(plan: planDict)

                    Spacer(minLength: 12)
                }
                .padding(18)
            }
        }
        .navigationTitle("Trip plan")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadRecommendationsIfNeeded() }
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

private struct TripPlanJSONResultsView: View {
    let plan: [String: Any]

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
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("\((item["time"] as? String) ?? "") • \((item["title"] as? String) ?? "")")
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(.white)
                                        Text(item["description"] as? String ?? "")
                                            .font(.caption)
                                            .foregroundStyle(.white.opacity(0.75))
                                    }
                                    .padding(.vertical, 4)
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
}
