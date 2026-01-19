import SwiftUI

struct AdsBannerView: View {
    var body: some View {
        LuxuryCard {
            HStack(spacing: 12) {
                Image(systemName: "megaphone.fill").foregroundStyle(Lx.gold)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Sponsored").font(.subheadline.weight(.semibold))
                    Text("Upgrade to Premium to remove ads.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
    }
}
