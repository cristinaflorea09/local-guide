import SwiftUI

/// Lightweight skeleton row used while listings are loading.
struct SkeletonListingRow: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.12))
                .frame(height: 160)
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.white.opacity(0.12))
                .frame(height: 16)
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.white.opacity(0.12))
                .frame(width: 180, height: 14)
        }
        .redacted(reason: .placeholder)
    }
}
