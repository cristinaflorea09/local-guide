import SwiftUI

struct ReviewsListView: View {
    let title: String
    let reviews: [Review]

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(reviews) { r in
                        LuxuryCard {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    StarRatingView(rating: r.rating)
                                    Spacer()
                                    if r.verified == true {
                                        Text("Verified booking")
                                            .font(.caption2.weight(.semibold))
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Lx.gold.opacity(0.18))
                                            .clipShape(Capsule())
                                            .foregroundStyle(Lx.gold)
                                    }
                                }
                                Text(r.comment.isEmpty ? "(No comment)" : r.comment)
                                    .foregroundStyle(.white)
                                    .font(.subheadline)
                                Text(r.createdAt.formatted(date: .abbreviated, time: .omitted))
                                    .foregroundStyle(.white.opacity(0.6))
                                    .font(.caption)
                            }
                        }
                    }
                }
                .padding(18)
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
