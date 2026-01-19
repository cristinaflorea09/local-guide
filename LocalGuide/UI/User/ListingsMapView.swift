import SwiftUI
import MapKit

/// MKMapView wrapper that supports clustering, category-colored pins, and smooth user tracking.
struct ListingsMapView: UIViewRepresentable {
    struct ListingPin: Identifiable, Hashable {
        enum Kind: String { case tour, experience }
        let id: String
        let kind: Kind
        let title: String
        let subtitle: String?
        let coordinate: CLLocationCoordinate2D
        let category: String?
        
        static func == (lhs: ListingPin, rhs: ListingPin) -> Bool {
            lhs.id == rhs.id
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }

    }

    @Binding var userTrackingMode: MKUserTrackingMode
    var pins: [ListingPin]
    var onSelect: (ListingPin) -> Void

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView(frame: .zero)
        map.delegate = context.coordinator
        map.showsUserLocation = true
        map.userTrackingMode = userTrackingMode
        map.pointOfInterestFilter = .excludingAll
        map.showsCompass = true
        map.showsScale = true
        map.isRotateEnabled = true
        map.isPitchEnabled = true

        // Prefer smoother follow behavior.
        map.setUserTrackingMode(userTrackingMode, animated: false)
        return map
    }

    func updateUIView(_ uiView: MKMapView, context: Context) {
        if uiView.userTrackingMode != userTrackingMode {
            uiView.setUserTrackingMode(userTrackingMode, animated: true)
        }

        // Update annotations.
        let existing = uiView.annotations.compactMap { $0 as? ListingAnnotation }
        uiView.removeAnnotations(existing)
        let newOnes = pins.map { ListingAnnotation(pin: $0) }
        uiView.addAnnotations(newOnes)
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, MKMapViewDelegate {
        let parent: ListingsMapView
        init(_ parent: ListingsMapView) { self.parent = parent }

        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            guard let ann = view.annotation as? ListingAnnotation else { return }
            parent.onSelect(ann.pin)
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if annotation is MKUserLocation { return nil }

            if let cluster = annotation as? MKClusterAnnotation {
                let id = "cluster"
                let v = mapView.dequeueReusableAnnotationView(withIdentifier: id) as? MKMarkerAnnotationView
                    ?? MKMarkerAnnotationView(annotation: cluster, reuseIdentifier: id)
                v.annotation = cluster
                v.markerTintColor = UIColor.systemGray
                v.glyphText = "\(cluster.memberAnnotations.count)"
                v.displayPriority = .required
                return v
            }

            guard let ann = annotation as? ListingAnnotation else { return nil }

            let id = "listing"
            let v = mapView.dequeueReusableAnnotationView(withIdentifier: id) as? MKMarkerAnnotationView
                ?? MKMarkerAnnotationView(annotation: ann, reuseIdentifier: id)
            v.annotation = ann

            v.clusteringIdentifier = "listing"
            v.displayPriority = .defaultHigh
            v.canShowCallout = true

            // Category-colored pins.
            v.markerTintColor = UIColor(color(for: ann.pin.category, kind: ann.pin.kind))
            v.glyphImage = UIImage(systemName: ann.pin.kind == .tour ? "figure.walk" : "sparkles")
            return v
        }

        private func color(for category: String?, kind: ListingPin.Kind) -> Color {
            // Stable mapping; fallback by kind.
            let c = (category ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if c.contains("food") || c.contains("culinary") { return .orange }
            if c.contains("hike") || c.contains("outdoor") || c.contains("nature") { return .green }
            if c.contains("museum") || c.contains("culture") || c.contains("history") { return .blue }
            if c.contains("night") || c.contains("party") { return .purple }
            if c.contains("wellness") || c.contains("spa") { return .pink }
            return kind == .tour ? .yellow : .teal
        }
    }
}

final class ListingAnnotation: NSObject, MKAnnotation {
    let pin: ListingsMapView.ListingPin
    init(pin: ListingsMapView.ListingPin) {
        self.pin = pin
        super.init()
    }
    var coordinate: CLLocationCoordinate2D { pin.coordinate }
    var title: String? { pin.title }
    var subtitle: String? { pin.subtitle }
}
