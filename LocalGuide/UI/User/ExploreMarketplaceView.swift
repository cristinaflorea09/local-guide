import SwiftUI

/// Unified marketplace exploration for travelers (Tours + Experiences).
struct ExploreMarketplaceView: View {
    enum Mode: String, CaseIterable {
        case tours = "Tours"
        case experiences = "Experiences"
    }

    @State private var mode: Mode = .tours

    var body: some View {
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

            if mode == .tours {
                ExploreToursView()
            } else {
                ExploreExperiencesView()
            }
        }
    }
}
