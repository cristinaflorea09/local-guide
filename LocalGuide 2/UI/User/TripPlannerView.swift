import SwiftUI

/// AI Trip Designer entry screen for travelers.
/// Contains a short description + CTA that opens the planner form.
struct TripPlannerView: View {
    @EnvironmentObject var appState: AppState
    @State private var showCreateForm = false
    @State private var plans: [TripPlan] = []
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("AI Trip Planner")
                            .font(.largeTitle.bold())
                            .foregroundStyle(.white)
                            .padding(.top, 8)

                        LuxuryCard {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Create an amazing trip with AI")
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                Text("Tell us where you're going and what you love — we'll build a day-by-day itinerary in seconds.")
                                    .font(.subheadline)
                                    .foregroundStyle(.white.opacity(0.75))
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                Button {
                                    Haptics.medium()
                                    showCreateForm = true
                                } label: {
                                    Text("Create trip plan")
                                }
                                .buttonStyle(LuxuryPrimaryButtonStyle())
                            }
                        }

                        // Show existing plans (most recent first)
                        if isLoading {
                            ProgressView().tint(Lx.gold)
                        } else if !plans.isEmpty {
                            LuxuryCard {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text("Your trip plans")
                                        .font(.headline)
                                        .foregroundStyle(.white)

                                    Divider().opacity(0.15)

                                    ForEach(plans) { tp in
                                        NavigationLink {
                                            TripPlanDetailView(tripPlan: tp)
                                        } label: {
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(tp.planTitleFallback)
                                                    .font(.subheadline.weight(.semibold))
                                                    .foregroundStyle(.white)
                                                    .lineLimit(1)
                                                Text("\(tp.city), \(tp.country)")
                                                    .font(.caption)
                                                    .foregroundStyle(.white.opacity(0.7))
                                                Text("\(tp.startDateISO) → \(tp.endDateISO)")
                                                    .font(.caption2)
                                                    .foregroundStyle(.white.opacity(0.6))
                                            }
                                        }
                                        .buttonStyle(.plain)

                                        if tp.id != plans.last?.id {
                                            Divider().opacity(0.12)
                                        }
                                    }
                                }
                            }
                        }

                        Spacer(minLength: 12)
                    }
                    .padding(18)
                }
            }
            .navigationTitle("Trip Planner")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(isPresented: $showCreateForm) {
                TripPlannerFormView()
            }
            .task { await refreshPlans() }
            .onAppear { Task { await refreshPlans() } }
            .onChange(of: showCreateForm) { presenting in
                // When returning from the create form, refresh the list so the newly
                // created plan shows up immediately.
                if !presenting {
                    Task { await refreshPlans() }
                }
            }
        }
    }

    private func refreshPlans() async {
        guard let uid = appState.session.firebaseUser?.uid else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            plans = try await FirestoreService.shared.listTripPlansForUser(uid: uid, limit: 20)
        } catch {
            plans = []
        }
    }
}

/// The actual AI Trip Designer form and results.
private struct TripPlannerFormView: View {
    @EnvironmentObject var appState: AppState

    @StateObject private var locationManager = LocationManager()

    @State private var country = "Romania"
    @State private var city = "Bucharest"
    @State private var showDestinationPicker = false
    @State private var startDate = Date()
    @State private var endDate = Calendar.current.date(byAdding: .day, value: 2, to: Date()) ?? Date()
    @State private var interestsText = "food, history, culture"
    @State private var budgetPerDayText = ""
    @State private var pace = "balanced"
    @State private var groupSize = 2

    @State private var isLoading = false
    @State private var errorText: String?
    @State private var plan: [String: Any]?
    @State private var tripPlanId: String?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    LuxuryCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Trip details")
                                .font(.title3.bold())
                                .foregroundStyle(.white)

                            Divider().opacity(0.15)

                            Button {
                                Haptics.light()
                                showDestinationPicker = true
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Destination")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(.secondary)
                                        Text("\(city), \(country)")
                                            .foregroundStyle(.white)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundStyle(.white.opacity(0.65))
                                }
                                .padding(.vertical, 8)
                            }
                            .buttonStyle(.plain)

                            DatePicker("Start", selection: $startDate, displayedComponents: [.date])
                                .datePickerStyle(.compact)
                            DatePicker("End", selection: $endDate, displayedComponents: [.date])
                                .datePickerStyle(.compact)

                            TextField("Interests (comma separated)", text: $interestsText)
                                .textFieldStyle(LuxuryTextFieldStyle())

                            TextField("Budget / day (optional)", text: $budgetPerDayText)
                                .keyboardType(.decimalPad)
                                .textFieldStyle(LuxuryTextFieldStyle())

                            Picker("Pace", selection: $pace) {
                                Text("Relaxed").tag("relaxed")
                                Text("Balanced").tag("balanced")
                                Text("Fast").tag("fast")
                            }
                            .pickerStyle(.segmented)

                            Stepper("Group size: \(groupSize)", value: $groupSize, in: 1...12)

                            Button {
                                Haptics.medium()
                                Task { await generate() }
                            } label: {
                                Text("Generate plan")
                            }
                            .buttonStyle(LuxuryPrimaryButtonStyle())
                        }
                    }

                    if let errorText {
                        LuxuryCard {
                            Text(errorText)
                                .foregroundStyle(.red)
                        }
                    }

                    if let plan {
                        TripPlanResultsView(plan: plan)
                    }

                    // Helpful identifier for debugging / support.
                    if let tripPlanId {
                        Text("Plan ID: \(tripPlanId)")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.6))
                            .padding(.horizontal, 4)
                    }
                }
                .padding(18)
            }

            if isLoading {
                VStack(spacing: 10) {
                    ProgressView().tint(Lx.gold)
                    Text("Generating...")
                        .foregroundStyle(.white.opacity(0.8))
                }
                .padding(18)
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
        .navigationTitle("Create plan")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showDestinationPicker) {
            DestinationPickerView(selectedCity: $city, selectedCountry: $country)
        }
        .onAppear {
            // Used only to improve recommendations (distance + nearby matching).
            locationManager.requestPermission()
        }
    }

    private func generate() async {
        errorText = nil
        isLoading = true
        defer { isLoading = false }

        do {
            let interests = interestsText
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

            let budget = Double(budgetPerDayText.replacingOccurrences(of: ",", with: "."))

            let code = appState.settings.languageCode
            let res = try await TripPlannerService.shared.generateTripPlan(
                country: country,
                city: city,
                startDate: startDate,
                endDate: endDate,
                interests: interests,
                budgetPerDay: budget,
                pace: pace,
                groupSize: groupSize,
                languageCode: code
            )
            self.tripPlanId = res.tripPlanId
            self.plan = res.plan

            // Link in-app tours/experiences to this plan using a heuristic matcher.
            // This prefers listings that match interests + budget + distance + availability within dates.
            await linkInAppRecommendations(
                tripPlanId: res.tripPlanId,
                inputs: .init(
                    city: city,
                    country: country,
                    startDate: startDate,
                    endDate: endDate,
                    interests: interests,
                    budgetPerDay: budget,
                    pace: pace,
                    groupSize: groupSize,
                    userLocation: locationManager.lastLocation
                )
            )
        } catch {
            self.errorText = error.localizedDescription
        }
    }

    private func linkInAppRecommendations(tripPlanId: String, inputs: TripRecommendationEngine.Inputs) async {
        do {
            // Fetch active listings in the same destination.
            let tours = try await FirestoreService.shared.getTours(city: inputs.city)
            let exps = try await FirestoreService.shared.getExperiences(city: inputs.city)

            let rec = await TripRecommendationEngine.shared.recommend(inputs: inputs, tours: tours, experiences: exps)

            try await FirestoreService.shared.updateTripPlan(
                tripPlanId: tripPlanId,
                fields: [
                    "recommendedTourIds": rec.tourIds,
                    "recommendedExperienceIds": rec.experienceIds
                ]
            )
        } catch {
            // Non-fatal; the plan still exists.
            print("Failed to link in-app recommendations: \(error)")
        }
    }
}

private struct TripPlanResultsView: View {
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

// MARK: - Destination picker (searchable)

private struct Destination: Identifiable, Hashable {
    let id = UUID()
    let city: String
    let country: String

    var label: String { "\(city), \(country)" }
}

/// Searchable picker for (city, country) pairs.
/// Keeps the input controlled to known destinations to help the AI create better plans.
private struct DestinationPickerView: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var selectedCity: String
    @Binding var selectedCountry: String

    @State private var query = ""

    // A curated list of popular destinations. You can extend this list anytime
    // (or later replace it with a remote dataset).
    private let destinations: [Destination] = [
        Destination(city: "Bucharest", country: "Romania"),
        Destination(city: "Cluj-Napoca", country: "Romania"),
        Destination(city: "Brasov", country: "Romania"),
        Destination(city: "Iasi", country: "Romania"),
        Destination(city: "Timisoara", country: "Romania"),
        Destination(city: "Sibiu", country: "Romania"),
        Destination(city: "Constanta", country: "Romania"),
        Destination(city: "Vienna", country: "Austria"),
        Destination(city: "Prague", country: "Czech Republic"),
        Destination(city: "Budapest", country: "Hungary"),
        Destination(city: "Paris", country: "France"),
        Destination(city: "Nice", country: "France"),
        Destination(city: "Rome", country: "Italy"),
        Destination(city: "Milan", country: "Italy"),
        Destination(city: "Barcelona", country: "Spain"),
        Destination(city: "Madrid", country: "Spain"),
        Destination(city: "London", country: "United Kingdom"),
        Destination(city: "Edinburgh", country: "United Kingdom"),
        Destination(city: "Amsterdam", country: "Netherlands"),
        Destination(city: "Berlin", country: "Germany"),
        Destination(city: "Munich", country: "Germany"),
        Destination(city: "Zurich", country: "Switzerland"),
        Destination(city: "Athens", country: "Greece"),
        Destination(city: "Santorini", country: "Greece"),
        Destination(city: "Istanbul", country: "Turkey"),
        Destination(city: "Dubai", country: "United Arab Emirates"),
        Destination(city: "New York", country: "United States"),
        Destination(city: "Los Angeles", country: "United States"),
        Destination(city: "Miami", country: "United States"),
        Destination(city: "Tokyo", country: "Japan"),
        Destination(city: "Kyoto", country: "Japan"),
        Destination(city: "Seoul", country: "South Korea"),
        Destination(city: "Bangkok", country: "Thailand"),
        Destination(city: "Singapore", country: "Singapore")
    ]

    private var filtered: [Destination] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return destinations }
        return destinations.filter {
            $0.city.localizedCaseInsensitiveContains(q)
            || $0.country.localizedCaseInsensitiveContains(q)
            || $0.label.localizedCaseInsensitiveContains(q)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(filtered) { d in
                    Button {
                        selectedCity = d.city
                        selectedCountry = d.country
                        dismiss()
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(d.city).font(.headline)
                            Text(d.country).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Destination")
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search city or country")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}
