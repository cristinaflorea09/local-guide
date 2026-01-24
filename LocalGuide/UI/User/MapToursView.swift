import SwiftUI
import MapKit
import CoreLocation
import UIKit

/// Map screen showing the user's location plus Tours and Experiences for the currently visible map area.
///
/// Behavior:
/// - On first open, centers on the user's location (once).
/// - As the user pans/zooms, listings are fetched for the visible region (debounced).
/// - Provides a search box to jump to a location and load listings there.
struct MapToursView: View {
    @State private var tours: [Tour] = []
    @State private var experiences: [Experience] = []
    @State private var isLoading = false

    @StateObject private var directory = ProfileDirectory()
    @StateObject private var locationManager = LocationManager()

    // MKUserTrackingMode is correct here because ListingsMapView is MKMapView-based.
    @State private var userTrackingMode: MKUserTrackingMode = .none
    @State private var didCenterOnUser = false

    @State private var selectedTour: Tour?
    @State private var selectedExperience: Experience?

    // Region binding for programmatic camera moves (search) and for reading current view.
    @State private var region: MKCoordinateRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 44.4268, longitude: 26.1025), // Bucharest fallback
        span: MKCoordinateSpan(latitudeDelta: 0.35, longitudeDelta: 0.35)
    )

    // Region debouncing
    @State private var regionDebounceTask: Task<Void, Never>?
    @State private var lastLoadedRegionKey: String = ""

    // Search UI
    @State private var searchText: String = ""
    @State private var searchResults: [MKMapItem] = []
    @FocusState private var searchFocused: Bool

    private func regionKey(_ r: MKCoordinateRegion) -> String {
        // coarse key so we don’t reload for tiny pans
        let lat = (r.center.latitude * 100).rounded() / 100
        let lon = (r.center.longitude * 100).rounded() / 100
        let spanLat = (r.span.latitudeDelta * 100).rounded() / 100
        let spanLon = (r.span.longitudeDelta * 100).rounded() / 100
        return "\(lat),\(lon),\(spanLat),\(spanLon)"
    }

    private func bounds(for r: MKCoordinateRegion) -> (minLat: Double, maxLat: Double, minLon: Double, maxLon: Double) {
        let minLat = r.center.latitude - r.span.latitudeDelta / 2
        let maxLat = r.center.latitude + r.span.latitudeDelta / 2
        let minLon = r.center.longitude - r.span.longitudeDelta / 2
        let maxLon = r.center.longitude + r.span.longitudeDelta / 2
        return (minLat, maxLat, minLon, maxLon)
    }

    /// Briefly enables follow to snap to user, then turns it off to prevent jumping.
    private func recenterOnce() {
        userTrackingMode = .follow
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            userTrackingMode = .none
        }
    }

    private var pins: [ListingsMapView.ListingPin] {
        let tourPins: [ListingsMapView.ListingPin] = tours.compactMap { t in
            guard let lat = t.latitude, let lon = t.longitude else { return nil }
            return ListingsMapView.ListingPin(
                id: "tour-\(t.id)",
                kind: .tour,
                title: t.title,
                subtitle: t.city,
                coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                category: t.category
            )
        }

        let expPins: [ListingsMapView.ListingPin] = experiences.compactMap { e in
            guard let lat = e.latitude, let lon = e.longitude else { return nil }
            return ListingsMapView.ListingPin(
                id: "exp-\(e.id)",
                kind: .experience,
                title: e.title,
                subtitle: e.city,
                coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                category: e.category
            )
        }

        return tourPins + expPins
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ListingsMapView(
                    userTrackingMode: $userTrackingMode,
                    region: $region,
                    pins: pins,
                    onSelect: { pin in
                        switch pin.kind {
                        case .tour:
                            let id = pin.id.replacingOccurrences(of: "tour-", with: "")
                            selectedTour = tours.first(where: { $0.id == id })
                        case .experience:
                            let id = pin.id.replacingOccurrences(of: "exp-", with: "")
                            selectedExperience = experiences.first(where: { $0.id == id })
                        }
                    },
                    onRegionChange: { newRegion in
                        // Debounce rapid pan/zoom updates.
                        regionDebounceTask?.cancel()
                        regionDebounceTask = Task {
                            try? await Task.sleep(nanoseconds: 450_000_000)
                            guard !Task.isCancelled else { return }
                            await loadForVisibleRegion(newRegion)
                        }
                    }
                )
                .ignoresSafeArea()

                // Top search overlay
                VStack(spacing: 10) {
                    searchBar
                    if !searchResults.isEmpty {
                        searchResultsList
                    }
                    Spacer()
                }
                .padding(.top, 8)
                .padding(.horizontal, 12)

                // Re-center button
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button {
                            recenterOnce()
                        } label: {
                            Image(systemName: "location.fill")
                                .font(.headline)
                                .padding(12)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Lx.gold.opacity(0.25), lineWidth: 1))
                        }
                        .padding(.trailing, 16)
                        .padding(.bottom, 24)
                    }
                }

//                if isLoading {
//                    VStack {
//                        LuxuryCard { ProgressView("Loading…").tint(Lx.gold) }
//                            .padding(.top, 70)
//                            .padding(.horizontal, 12)
//                        Spacer()
//                    }
//                }

                // Permission / failure hint
                if locationManager.authorization == .denied || locationManager.authorization == .restricted {
                    VStack {
                        Spacer()
                        LuxuryCard {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Location is off")
                                    .font(.headline)
                                Text("Enable location to see your position and nearby tours/experiences on the map.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Button {
                                    if let url = URL(string: UIApplication.openSettingsURLString) {
                                        UIApplication.shared.open(url)
                                    }
                                } label: {
                                    Text("Open Settings")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(Lx.gold)
                            }
                        }
                        .padding()
                    }
                } else if locationManager.didFail {
                    VStack {
                        Spacer()
                        LuxuryCard {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Can't get your location")
                                    .font(.headline)
                                Text("If you're on the Simulator, set a simulated location in Xcode (Debug > Location).")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding()
                    }
                }
            }
            .task {
                locationManager.requestPermission()
                // If location already exists, center once; otherwise wait for onChange.
                if let loc = locationManager.lastLocation, !didCenterOnUser {
                    didCenterOnUser = true
                    region = MKCoordinateRegion(
                        center: loc.coordinate,
                        span: MKCoordinateSpan(latitudeDelta: 0.25, longitudeDelta: 0.25)
                    )
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { recenterOnce() }
                }
                // Initial load for whatever region is visible.
                await loadForVisibleRegion(region)
            }
            .onChange(of: locationManager.lastLocation) { newLoc in
                guard let loc = newLoc, !didCenterOnUser else { return }
                didCenterOnUser = true
                region = MKCoordinateRegion(
                    center: loc.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.25, longitudeDelta: 0.25)
                )
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { recenterOnce() }
            }
            .fullScreenCover(item: $selectedTour) { tour in
                NavigationStack {
                    TourDetailsView(tour: tour)
                }
            }
            .fullScreenCover(item: $selectedExperience) { exp in
                NavigationStack {
                    ExperienceDetailsView(experience: exp)
                }
            }
        }
    }

    // MARK: - Search UI

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("Search a place (e.g. Sibiu)", text: $searchText)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled(true)
                .focused($searchFocused)
                .submitLabel(.search)
                .onSubmit { Task { await runSearch() } }

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                    searchResults = []
                    searchFocused = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.08), lineWidth: 1))
    }

    private var searchResultsList: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(searchResults.indices, id: \.self) { idx in
                let item = searchResults[idx]
                Button {
                    jumpToMapItem(item)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.name ?? "Unknown")
                            .font(.headline)
                            .foregroundStyle(.white)
                        if let subtitle = item.placemark.title {
                            Text(subtitle)
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.7))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.plain)

                if idx != searchResults.count - 1 {
                    Divider().overlay(.white.opacity(0.06))
                }
            }
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.08), lineWidth: 1))
    }

    private func runSearch() async {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return }

        let req = MKLocalSearch.Request()
        req.naturalLanguageQuery = q
        req.region = region
        do {
            let resp = try await MKLocalSearch(request: req).start()
            searchResults = Array(resp.mapItems.prefix(6))
        } catch {
            searchResults = []
        }
    }

    private func jumpToMapItem(_ item: MKMapItem) {
        let c = item.placemark.coordinate
        userTrackingMode = .none
        // Move camera; ListingsMapView will animate to this region.
        region = MKCoordinateRegion(
            center: c,
            span: MKCoordinateSpan(latitudeDelta: 0.22, longitudeDelta: 0.22)
        )
        searchResults = []
        searchFocused = false
        // The region move will trigger onRegionChange -> loadForVisibleRegion.
    }

    // MARK: - Loading

    private func loadForVisibleRegion(_ region: MKCoordinateRegion) async {
        let key = regionKey(region)
        if key == lastLoadedRegionKey { return }
        lastLoadedRegionKey = key

        isLoading = true
        defer { isLoading = false }

        let b = bounds(for: region)

        do {
            // Query server by latitude range and filter longitude locally.
            let tourCandidates = try await FirestoreService.shared.getToursByLatitudeRange(
                minLat: b.minLat, maxLat: b.maxLat, limit: 600
            )
            let expCandidates = try await FirestoreService.shared.getExperiencesByLatitudeRange(
                minLat: b.minLat, maxLat: b.maxLat, limit: 600
            )

            tours = tourCandidates.filter { t in
                guard let lat = t.latitude, let lon = t.longitude else { return false }
                return lat >= b.minLat && lat <= b.maxLat && lon >= b.minLon && lon <= b.maxLon && (t.active == true)
            }
            experiences = expCandidates.filter { e in
                guard let lat = e.latitude, let lon = e.longitude else { return false }
                return lat >= b.minLat && lat <= b.maxLat && lon >= b.minLon && lon <= b.maxLon && (e.active == true)
            }

            // Prefetch profiles used by callouts/details.
            for t in tours { await directory.loadGuideIfNeeded(t.guideId) }
            for e in experiences { await directory.loadHostIfNeeded(e.hostId) }
        } catch {
            print("Map region load failed:", error.localizedDescription)
        }
    }
}
