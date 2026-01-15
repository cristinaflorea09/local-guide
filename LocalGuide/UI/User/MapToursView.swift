import SwiftUI
import MapKit

struct MapToursView: View {
    @State private var tours: [Tour] = []
    @State private var isLoading = false
    @StateObject private var directory = ProfileDirectory()
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 52.2297, longitude: 21.0122),
        span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)
    )

    private var mapTours: [Tour] { tours.filter { $0.latitude != nil && $0.longitude != nil } }

    var body: some View {
        NavigationStack {
            ZStack {
                Map(coordinateRegion: $region, annotationItems: mapTours) { tour in
                    MapAnnotation(coordinate: CLLocationCoordinate2D(latitude: tour.latitude ?? 0, longitude: tour.longitude ?? 0)) {
                        NavigationLink { TourDetailsView(tour: tour) } label: {
                            VStack(spacing: 6) {
                                AvatarView(url: directory.guide(tour.guideId)?.photoURL, size: 22)
                                Image(systemName: "mappin.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(Lx.gold)
                                Text("€\(tour.price, specifier: "%.0f")")
                                    .font(.caption2.weight(.semibold))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 5)
                                    .background(.ultraThinMaterial)
                                    .clipShape(Capsule())
                                    .overlay(Capsule().stroke(Lx.gold.opacity(0.22), lineWidth: 1))
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .ignoresSafeArea()

                if isLoading {
                    LuxuryCard { ProgressView("Loading…").tint(Lx.gold) }
                        .padding()
                }
            }
            .navigationTitle("Map")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { Task { await load() } } label: {
                        Image(systemName: "arrow.clockwise").foregroundStyle(Lx.gold)
                    }
                }
            }
            .onAppear { Task { await load() } }
        }
    }

    private func load() async {
        isLoading = true
        do {
            tours = try await FirestoreService.shared.getTours(city: nil)
            for t in tours { await directory.loadGuideIfNeeded(t.guideId) }
        } catch {
            tours = []
        }
        isLoading = false
    }
}
