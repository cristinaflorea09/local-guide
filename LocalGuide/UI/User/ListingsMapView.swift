import SwiftUI
import MapKit
import CoreLocation
import UIKit

/// MKMapView wrapper that supports clustering, category-colored pins, region binding, and debounced region callbacks.
///
/// Optimizations:
/// - Diff-based annotation updates (avoid remove-all/add-all)
/// - Debounced regionDidChange notifications (prevents query spam)
/// - Stable clustering identifiers
struct ListingsMapView: UIViewRepresentable {

    struct ListingPin: Identifiable, Hashable {
        enum Kind: String { case tour, experience }

        let id: String
        let kind: Kind
        let title: String
        let subtitle: String?
        let coordinate: CLLocationCoordinate2D
        let category: String?

        static func == (lhs: ListingPin, rhs: ListingPin) -> Bool { lhs.id == rhs.id }
        func hash(into hasher: inout Hasher) { hasher.combine(id) }
    }

    // MARK: Inputs

    @Binding var userTrackingMode: MKUserTrackingMode

    /// Current map region (lets MapToursView jump to a searched place).
    @Binding var region: MKCoordinateRegion

    var pins: [ListingPin]
    var onSelect: (ListingPin) -> Void

    /// Called when the visible map region changes (pan/zoom or user tracking). Debounced.
    var onRegionChange: ((MKCoordinateRegion) -> Void)? = nil

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView(frame: .zero)
        map.delegate = context.coordinator
        map.showsUserLocation = true
        map.pointOfInterestFilter = .excludingAll
        map.showsCompass = true
        map.showsScale = true
        map.isRotateEnabled = true
        map.isPitchEnabled = true

        // Start at provided region.
        map.setRegion(region, animated: false)

        // Prefer smoother follow behavior.
        map.setUserTrackingMode(userTrackingMode, animated: false)

        return map
    }

    func updateUIView(_ uiView: MKMapView, context: Context) {
        if uiView.userTrackingMode != userTrackingMode {
            uiView.setUserTrackingMode(userTrackingMode, animated: true)
        }

        // If parent sets region (e.g., search), move camera without triggering a load loop.
        if !context.coordinator.isApplyingRegion {
            let needsMove = !context.coordinator.isRegion(uiView.region, approximatelyEqualTo: region)
            if needsMove {
                context.coordinator.isApplyingRegion = true
                uiView.setRegion(region, animated: true)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    context.coordinator.isApplyingRegion = false
                }
            }
        }

        // ✅ Diff-based annotation updates
        context.coordinator.applyPins(pins, on: uiView)
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    // MARK: - Coordinator

    final class Coordinator: NSObject, MKMapViewDelegate {
        let parent: ListingsMapView

        // Diff state
        private var annotationsById: [String: ListingAnnotation] = [:]

        // Region debounce state
        private var pendingRegionWorkItem: DispatchWorkItem?
        private var lastReportedRegionCenter: CLLocationCoordinate2D?
        private var lastReportedSpan: MKCoordinateSpan?

        // Prevent feedback loop when parent sets region.
        var isApplyingRegion: Bool = false

        init(_ parent: ListingsMapView) {
            self.parent = parent
        }

        // MARK: Selection

        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            guard let ann = view.annotation as? ListingAnnotation else { return }
            parent.onSelect(ann.pin)
        }

        // MARK: Region callbacks

        func mapViewDidFinishLoadingMap(_ mapView: MKMapView) {
            // Fire initial callback once the map has rendered.
            reportRegionDebounced(mapView.region)
        }

        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            // Keep SwiftUI binding in sync with real map camera.
            if !isApplyingRegion {
                parent.region = mapView.region
            }
            reportRegionDebounced(mapView.region)
        }

        private func reportRegionDebounced(_ region: MKCoordinateRegion) {
            pendingRegionWorkItem?.cancel()

            // Avoid re-sending essentially identical updates.
            let center = region.center
            let span = region.span

            let isSameCenter: Bool
            if let last = lastReportedRegionCenter {
                let dLat = abs(last.latitude - center.latitude)
                let dLon = abs(last.longitude - center.longitude)
                isSameCenter = dLat < 0.001 && dLon < 0.001
            } else {
                isSameCenter = false
            }

            let isSameSpan: Bool
            if let lastSpan = lastReportedSpan {
                isSameSpan = abs(lastSpan.latitudeDelta - span.latitudeDelta) < 0.001 && abs(lastSpan.longitudeDelta - span.longitudeDelta) < 0.001
            } else {
                isSameSpan = false
            }

            if isSameCenter && isSameSpan { return }

            let work = DispatchWorkItem { [weak self] in
                guard let self else { return }
                self.lastReportedRegionCenter = center
                self.lastReportedSpan = span
                self.parent.onRegionChange?(region)
            }
            pendingRegionWorkItem = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45, execute: work)
        }

        func isRegion(_ a: MKCoordinateRegion, approximatelyEqualTo b: MKCoordinateRegion) -> Bool {
            let dLat = abs(a.center.latitude - b.center.latitude)
            let dLon = abs(a.center.longitude - b.center.longitude)
            let dSpanLat = abs(a.span.latitudeDelta - b.span.latitudeDelta)
            let dSpanLon = abs(a.span.longitudeDelta - b.span.longitudeDelta)
            return dLat < 0.0005 && dLon < 0.0005 && dSpanLat < 0.0005 && dSpanLon < 0.0005
        }

        // MARK: Annotation diff

        func applyPins(_ newPins: [ListingPin], on mapView: MKMapView) {
            let newIds = Set(newPins.map { $0.id })
            let oldIds = Set(annotationsById.keys)

            // Remove missing
            let toRemove = oldIds.subtracting(newIds)
            if !toRemove.isEmpty {
                let anns = toRemove.compactMap { annotationsById[$0] }
                for a in anns { annotationsById.removeValue(forKey: a.pin.id) }
                mapView.removeAnnotations(anns)
            }

            // Add new
            let toAdd = newIds.subtracting(oldIds)
            if !toAdd.isEmpty {
                let addPins = newPins.filter { toAdd.contains($0.id) }
                let anns = addPins.map { ListingAnnotation(pin: $0) }
                for a in anns { annotationsById[a.pin.id] = a }
                mapView.addAnnotations(anns)
            }

            // Update existing (only if changed)
            for pin in newPins {
                guard let ann = annotationsById[pin.id] else { continue }
                if ann.pin != pin {
                    ann.update(with: pin)
                }
            }
        }

        // MARK: Annotation views

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
                v.canShowCallout = false
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
            v.markerTintColor = UIColor(color(for: ann.pin.category, kind: ann.pin.kind))
            v.glyphImage = UIImage(systemName: ann.pin.kind == .tour ? "figure.walk" : "sparkles")
            return v
        }

        private func color(for category: String?, kind: ListingPin.Kind) -> Color {
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
    private(set) var pin: ListingsMapView.ListingPin

    init(pin: ListingsMapView.ListingPin) {
        self.pin = pin
        super.init()
    }

    var coordinate: CLLocationCoordinate2D { pin.coordinate }
    var title: String? { pin.title }
    var subtitle: String? { pin.subtitle }

    func update(with newPin: ListingsMapView.ListingPin) {
        willChangeValue(forKey: "coordinate")
        pin = newPin
        didChangeValue(forKey: "coordinate")
    }
}
