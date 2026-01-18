import SwiftUI

struct ExploreExperiencesView: View {
    @EnvironmentObject var appState: AppState
    @State private var experiences: [Experience] = []
    @State private var loading = false
    @State private var cityFilter: String = ""
    @State private var sortOption: ListingSortOption = .bestRated
    @State private var nextSlotByExpId: [String: Date] = [:]

    var filtered: [Experience] {
        if cityFilter.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return experiences }
        return experiences.filter { $0.city.localizedCaseInsensitiveContains(cityFilter) }
    }

    private func sortedExperiences(appState: AppState) -> [Experience] {
        switch sortOption {
        case .newest:
            return filtered.sorted { $0.createdAt > $1.createdAt }
        case .mostReviewed:
            return filtered.sorted { ($0.ratingCount ?? 0) > ($1.ratingCount ?? 0) }
        case .bestRated:
            return filtered.sorted { ($0.ratingAvg ?? 0) > ($1.ratingAvg ?? 0) }
        case .topThisWeek:
            // Removed dependency on appState.directory; rely on experience's own scores
            return filtered.sorted {
                let a = $0.weeklyScore ?? 0
                let b = $1.weeklyScore ?? 0
                if a == b {
                    let ca = $0.ratingCount ?? 0
                    let cb = $1.ratingCount ?? 0
                    return ca > cb
                }
                return a > b
            }
        case .bestWeighted:
            // Removed dependency on appState.directory; rely on experience's own weightedScore or ratingAvg
            return filtered.sorted {
                let a = $0.weightedScore ?? ($0.ratingAvg ?? 0)
                let b = $1.weightedScore ?? ($1.ratingAvg ?? 0)
                if a == b {
                    let ca = $0.ratingCount ?? 0
                    let cb = $1.ratingCount ?? 0
                    return ca > cb
                }
                return a > b
            }
        case .soonestAvailable:
            return filtered.sorted { (nextSlotByExpId[$0.id] ?? .distantFuture) < (nextSlotByExpId[$1.id] ?? .distantFuture) }
        }
    }

    var body: some View {
        NavigationView {
            ZStack {
                let currentAppState = appState
                let sorted = sortedExperiences(appState: currentAppState)

                Color.black.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        LuxuryCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Experiences")
                                    .font(.title2.bold())
                                    .foregroundStyle(.white)
                                Text("Authentic local activities hosted by creators.")
                                    .font(.subheadline)
                                    .foregroundStyle(.white.opacity(0.75))
                                TextField("Filter by city", text: $cityFilter)
                                    .textFieldStyle(LuxuryTextFieldStyle())
                                HStack {
                                    Text("Sort")
                                        .foregroundStyle(.white.opacity(0.85))
                                        .font(.subheadline.weight(.semibold))
                                    Spacer()
                                    Picker("Sort", selection: $sortOption) {
                                        ForEach(ListingSortOption.allCases) { opt in
                                            Text(opt.title).tag(opt)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                    .tint(Lx.gold)
                                }
                            }
                        }

                        LazyVStack(spacing: 14) {
                            ForEach(sorted) { exp in
                                NavigationLink {
                                    ExperienceDetailsView(experience: exp)
                                } label: {
                                    ExperienceCard(experience: exp)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(18)
                }

                if loading {
                    ProgressView().tint(Lx.gold)
                }
            }
            .navigationTitle("Experiences")
            .navigationBarTitleDisplayMode(.inline)
            .task { await load() }
            .onReceive(Timer.publish(every: 30, on: .main, in: .common).autoconnect()) { _ in
                Task { await load() }
            }
            .refreshable { await load() }
        }
    }

    private func load() async {
        if loading { return }
        loading = true
        defer { loading = false }
        do {
            experiences = try await FirestoreService.shared.getExperiences(city: nil)
            await computeNextSlots()
        } catch {
            experiences = []
        }
    }

    private func computeNextSlots() async {
        var map: [String: Date] = [:]
        await withTaskGroup(of: (String, Date?).self) { g in
            for e in experiences {
                g.addTask {
                    let slot = try? await FirestoreService.shared.getNextAvailability(listingType: "experience", listingId: e.id)
                    return (e.id, slot?.start)
                }
            }
            for await (id, date) in g {
                if let date { map[id] = date }
            }
        }
        nextSlotByExpId = map
    }
}
