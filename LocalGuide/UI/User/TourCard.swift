import SwiftUI

struct TourCard: View {
    let tour: Tour
    var subtitle: String? = nil
    var guideName: String? = nil
    var guidePhotoURL: String? = nil
    var guideRating: Double? = nil
    var reviewCount: Int? = nil

    var body: some View {
        LuxuryCard {
            VStack(alignment: .leading, spacing: 10) {
                ZStack(alignment: .topLeading) {
                    cover
                        .frame(height: 180)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Lx.gold.opacity(0.22), lineWidth: 1)
                        )

                    VStack(alignment: .leading, spacing: 6) {
                        LuxuryPill(text: tour.city)
                        Text(tour.title)
                            .font(.headline)
                            .foregroundStyle(.white)
                            .lineLimit(2)
                        Text("\(tour.durationMinutes) min • Up to \(tour.maxPeople)")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.75))
                    }
                    .padding(12)

                    VStack {
                        Spacer()
                        HStack {
                            Text("€\(tour.price, specifier: "%.2f")")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(.black.opacity(0.35))
                                .clipShape(Capsule())
                                .overlay(Capsule().stroke(Lx.gold.opacity(0.25), lineWidth: 1))
                            Spacer()
                        }
                        .padding(12)
                    }
                }

                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }

                if guideName != nil || guideRating != nil {
                    HStack(spacing: 10) {
                        AvatarView(url: guidePhotoURL, size: 30)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(guideName ?? "Guide")
                                .font(.subheadline.weight(.semibold))
                            if let r = guideRating, r > 0 {
                                HStack(spacing: 6) {
                                    StarRatingView(rating: r, size: 12)
                                    if let c = reviewCount {
                                        Text("(\(c))")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            } else {
                                Text("New guide").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .transition(.opacity.combined(with: .scale(scale: 0.98)))
    }

    @ViewBuilder
    private var cover: some View {
        if let urlStr = tour.coverPhotoURL, let url = URL(string: urlStr) {
            CachedAsyncImage(url: url) { img in
                img.resizable().scaledToFill()
                    .overlay(LinearGradient(colors: [Color.black.opacity(0.18), Color.black.opacity(0.75)],
                                           startPoint: .top, endPoint: .bottom))
            } placeholder: {
                fallbackCover.overlay(ProgressView().tint(Lx.gold))
            }
        } else {
            fallbackCover
        }
    }

    private var fallbackCover: some View {
        LinearGradient(colors: [Color.black.opacity(0.85), Color.black.opacity(0.55)],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}
