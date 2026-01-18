import SwiftUI

/// AI Trip Designer for travelers.
struct TripPlannerView: View {
    @EnvironmentObject var appState: AppState

    @State private var country = "Romania"
    @State private var city = "Bucharest"
    @State private var startDate = Date()
    @State private var endDate = Calendar.current.date(byAdding: .day, value: 2, to: Date()) ?? Date()
    @State private var interestsText = "food, history, culture"
    @State private var budgetPerDayText = ""
    @State private var pace = "balanced"
    @State private var groupSize = 2

    @State private var isLoading = false
    @State private var errorText: String?
    @State private var plan: [String: Any]?

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        LuxuryCard {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("AI Trip Designer")
                                    .font(.title2.bold())
                                    .foregroundStyle(.white)
                                Text("Build a personalized day-by-day plan in seconds.")
                                    .font(.subheadline)
                                    .foregroundStyle(.white.opacity(0.75))

                                Divider().opacity(0.15)

                                TextField("Country", text: $country)
                                    .textFieldStyle(LuxuryTextFieldStyle())
                                TextField("City", text: $city)
                                    .textFieldStyle(LuxuryTextFieldStyle())

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
            .navigationTitle("Trip Planner")
            .navigationBarTitleDisplayMode(.inline)
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
            self.plan = res.plan
        } catch {
            self.errorText = error.localizedDescription
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
                                Text(theme).font(.caption).foregroundStyle(.secondary)
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
