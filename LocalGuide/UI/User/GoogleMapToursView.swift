import SwiftUI

#if canImport(GoogleMaps)
import GoogleMaps

struct GoogleMapToursView: View {
    @State private var tours: [Tour] = []
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            ZStack {
                GoogleMapView(tours: tours)
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
        do { tours = try await FirestoreService.shared.getTours(city: nil) }
        catch { tours = [] }
        isLoading = false
    }
}

struct GoogleMapView: UIViewRepresentable {
    let tours: [Tour]

    func makeUIView(context: Context) -> GMSMapView {
        let camera = GMSCameraPosition(latitude: 52.2297, longitude: 21.0122, zoom: 10)
        let map = GMSMapView(frame: .zero, camera: camera)
        return map
    }

    func updateUIView(_ map: GMSMapView, context: Context) {
        map.clear()
        for t in tours {
            guard let lat = t.latitude, let lng = t.longitude else { continue }
            let marker = GMSMarker(position: CLLocationCoordinate2D(latitude: lat, longitude: lng))
            marker.title = t.title
            marker.snippet = "€\(t.price)"
            marker.map = map
        }
    }
}
#else
// Fallback to Apple Maps if GoogleMaps SDK not added yet.
struct GoogleMapToursView: View {
    var body: some View {
        MapToursView()
    }
}
#endif
