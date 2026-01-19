import SwiftUI
import MapKit
import CoreLocation
import UIKit

/// Map screen showing the user's location plus nearby Tours and Experiences.
struct MapToursView: View {
    @State private var tours: [Tour] = []
    @State private var experiences: [Experience] = []
    @State private var isLoading = false

    @StateObject private var directory = ProfileDirectory()
    @StateObject private var locationManager = LocationManager()

    // Using MKUserTrackingMode is correct here because ListingsMapView is MKMapView-based.
    @State private var userTrackingMode: MKUserTrackingMode = .followWithHeading

    @State private var selectedTour: Tour?
    @State private var selectedExperience: Experience?

    private var pins: [ListingsMapView.ListingPin] {
        let tourPins: [ListingsMapView.ListingPin] = tours.compactMap { (t) -> ListingsMapView.ListingPin? in
            guard let lat = t.latitude, let lon = t.longitude else { return nil }
            return ListingsMapView.ListingPin(
                id: "tour-\(t.id)",
                kind: .tour,
                title: t.title,
                subtitle: t.city,
                coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                category: t.category ?? "Tour"
            )
        }

        let expPins: [ListingsMapView.ListingPin] = experiences.compactMap { (e) -> ListingsMapView.ListingPin? in
            guard let lat = e.latitude, let lon = e.longitude else { return nil }
            return ListingsMapView.ListingPin(
                id: "exp-\(e.id)",
                kind: .experience,
                title: e.title,
                subtitle: e.city,
                coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                category: e.category ?? "Experience"
            )
        }

        let allPins = tourPins + expPins

        // If we have location, show nearby items only.
        guard let userLoc = locationManager.lastLocation else {
            return allPins
        }

        let maxKm: Double = 50
        func isNearby(_ c: CLLocationCoordinate2D) -> Bool {
            let d = userLoc.distance(from: CLLocation(latitude: c.latitude, longitude: c.longitude))
            return (d / 1000.0) <= maxKm
        }

        return allPins.filter { isNearby($0.coordinate) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ListingsMapView(userTrackingMode: $userTrackingMode, pins: pins) { pin in
                    switch pin.kind {
                    case .tour:
                        let id = pin.id.replacingOccurrences(of: "tour-", with: "")
                        selectedTour = tours.first(where: { $0.id == id })
                    case .experience:
                        let id = pin.id.replacingOccurrences(of: "exp-", with: "")
                        selectedExperience = experiences.first(where: { $0.id == id })
                    }
                }
                .ignoresSafeArea()

                // Re-center / follow button
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button {
                            userTrackingMode = .followWithHeading
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

                if isLoading {
                    LuxuryCard { ProgressView("Loading…").tint(Lx.gold) }
                        .padding()
                }

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
            .navigationTitle("Map")
            .task {
                locationManager.requestPermission()
                await load()
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
        }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            tours = try await FirestoreService.shared.getTours(city: nil)
            experiences = try await FirestoreService.shared.getExperiences(city: nil)
            for t in tours { await directory.loadGuideIfNeeded(t.guideId) }
            for e in experiences { await directory.loadHostIfNeeded(e.hostId) }
        } catch {
            tours = []
            experiences = []
        }
    }
}
