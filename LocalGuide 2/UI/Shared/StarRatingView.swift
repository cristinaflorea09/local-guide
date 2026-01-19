import SwiftUI

/// Lightweight star rating component used throughout the app.
///
/// - Display-only: pass `rating` as Double/Int.
/// - Interactive: provide `onChange` to set 1-5.
struct StarRatingView: View {
    private let maxStars = 5
    private let value: Double
    private let size: CGFloat
    private let onChange: ((Int) -> Void)?

    init(rating: Double, size: CGFloat = 14, onChange: ((Int) -> Void)? = nil) {
        self.value = rating
        self.size = size
        self.onChange = onChange
    }

    init(rating: Int, size: CGFloat = 14, onChange: ((Int) -> Void)? = nil) {
        self.value = Double(rating)
        self.size = size
        self.onChange = onChange
    }

    var body: some View {
        HStack(spacing: 4) {
            ForEach(1...maxStars, id: \.self) { i in
                let filled = Double(i) <= value.rounded(.toNearestOrAwayFromZero)
                Image(systemName: filled ? "star.fill" : "star")
                    .font(.system(size: size))
                    .foregroundStyle(filled ? Lx.gold : .white.opacity(0.35))
                    .contentShape(Rectangle())
                    .onTapGesture {
                        guard let onChange else { return }
                        onChange(i)
                    }
            }
        }
        .accessibilityLabel("Rating")
        .accessibilityValue("\(Int(value.rounded())) out of 5")
    }
}
