import SwiftUI

struct StarRatingView: View {
    let rating: Double
    var max: Int = 5
    var size: CGFloat = 14

    var body: some View {
        HStack(spacing: 3) {
            ForEach(1...max, id: \.self) { i in
                Image(systemName: symbol(for: Double(i)))
                    .font(.system(size: size))
                    .foregroundStyle(Lx.gold)
            }
            Text(String(format: "%.1f", rating))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }

    private func symbol(for i: Double) -> String {
        if rating >= i { return "star.fill" }
        if rating >= i - 0.5 { return "star.leadinghalf.filled" }
        return "star"
    }
}
