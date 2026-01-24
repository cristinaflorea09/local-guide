import SwiftUI

/// Unified marketplace exploration for travelers (Tours + Experiences).
struct ExploreMarketplaceView: View {
    enum Mode: String, CaseIterable {
        case tours = "Tours"
        case experiences = "Experiences"
    }

    @State private var mode: Mode = .tours
    @StateObject private var filters = MarketplaceFilterState()
    @State private var showFilters = false
    @FocusState private var isSearchFocused: Bool

    @State private var selectedTour: Tour?
    @State private var selectedExperience: Experience?

    @State private var stickyHeaderHeight: CGFloat = 0

    private struct HeaderHeightKey: PreferenceKey {
        static var defaultValue: CGFloat = 0
        static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
            value = nextValue()
        }
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.ignoresSafeArea()

            // Content scrolls under a sticky header.
            Group {
                if mode == .tours {
                    ExploreToursView(onSelect: { t in
                        isSearchFocused = false
                        selectedTour = t
                    })
                        .environmentObject(filters)
                } else {
                    ExploreExperiencesView(onSelect: { e in
                        isSearchFocused = false
                        selectedExperience = e
                    })
                        .environmentObject(filters)
                }
            }
            .padding(.top, stickyHeaderHeight)

            stickyHeader
                .background(Color.black)
                .zIndex(2)
        }
        .sheet(isPresented: $showFilters) {
            MarketplaceFiltersSheet(filters: filters)
        }
        .fullScreenCover(item: $selectedTour) { tour in
            NavigationStack {
                TourDetailsView(tour: tour)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Close") { selectedTour = nil }
                                .foregroundStyle(Lx.gold)
                        }
                    }
            }
        }
        .fullScreenCover(item: $selectedExperience) { exp in
            NavigationStack {
                ExperienceDetailsView(experience: exp)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Close") { selectedExperience = nil }
                                .foregroundStyle(Lx.gold)
                        }
                    }
            }
        }
        .onTapGesture {
            // Dismiss keyboard when tapping outside the search field
            isSearchFocused = false
        }
        .onAppear {
            // Ensure search is not active on initial load.
            isSearchFocused = false
        }
        .onChange(of: mode) { _, _ in
            // Reset search/filters when switching between Tours and Experiences.
            filters.clear()
            isSearchFocused = false
        }
    }

    private var stickyHeader: some View {
        VStack(spacing: 0) {
            Picker("Marketplace", selection: $mode) {
                ForEach(Mode.allCases, id: \.self) { m in
                    Text(m.rawValue).tag(m)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 18)
            .padding(.top, 10)
            .padding(.bottom, 6)

            // Search + Filter + Sort (prominent)
            LuxuryCard {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(Lx.gold)

                    TextField("Search tours & experiences", text: $filters.query)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .focused($isSearchFocused)
                        .foregroundStyle(.white)

                    Spacer(minLength: 0)

                    // Near Me (default ON)
                    Menu {
                        Toggle("Near me", isOn: $filters.nearMeEnabled)
                        Divider()
                        ForEach([5, 10, 25, 50, 100], id: \.self) { km in
                            Button {
                                filters.nearMeEnabled = true
                                filters.nearMeRadiusKm = Double(km)
                            } label: {
                                if filters.nearMeEnabled && Int(filters.nearMeRadiusKm) == km {
                                    Label("\(km) km", systemImage: "checkmark")
                                } else {
                                    Text("\(km) km")
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: filters.nearMeEnabled ? "location.fill" : "location")
                            Text("Near me")
                                .font(.caption.weight(.semibold))
                            Text("\(Int(filters.nearMeRadiusKm))km")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .foregroundStyle(Lx.gold)
                    }
                    .buttonStyle(.plain)

                    Button {
                        showFilters = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "line.3.horizontal.decrease.circle")
                            if filters.activeFiltersCount > 0 {
                                Text("\(filters.activeFiltersCount)")
                                    .font(.caption.weight(.bold))
                            }
                        }
                        .foregroundStyle(Lx.gold)
                    }
                    .buttonStyle(.plain)

                    Menu {
                        Picker("Sort", selection: $filters.sortOption) {
                            ForEach(ListingSortOption.allCases) { opt in
                                Text(opt.title).tag(opt)
                            }
                        }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down.circle")
                            .foregroundStyle(Lx.gold)
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 8)
        }
        .background(
            GeometryReader { geo in
                Color.clear
                    .preference(key: HeaderHeightKey.self, value: geo.size.height)
            }
        )
        .onPreferenceChange(HeaderHeightKey.self) { stickyHeaderHeight = $0 }
    }
}
