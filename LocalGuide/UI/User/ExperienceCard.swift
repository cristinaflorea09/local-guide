import SwiftUI

struct ExperienceCard: View {
    let experience: Experience

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
                        LuxuryPill(text: experience.city)
                        Text(experience.title)
                            .font(.headline)
                            .foregroundStyle(.white)
                            .lineLimit(2)
                        Text("\(experience.durationMinutes) min • Up to \(experience.maxPeople)")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.75))
                    }
                    .padding(12)

                    VStack {
                        Spacer()
                        HStack {
                            if let avg = experience.ratingAvg, let count = experience.ratingCount, count > 0 {
                                HStack(spacing: 6) {
                                    StarRatingView(rating: avg, size: 11)
                                    Text("\(count)").font(.caption2).foregroundStyle(.white.opacity(0.9))
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(.black.opacity(0.35))
                                .clipShape(Capsule())
                                .overlay(Capsule().stroke(Lx.gold.opacity(0.25), lineWidth: 1))
                            }
                            Text(experience.price, format: .currency(code: "EUR"))
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

                Text(experience.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
        }
    }

    @ViewBuilder
    private var cover: some View {
        if let urlStr = experience.coverPhotoURL, let url = URL(string: urlStr) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let img):
                    img.resizable().scaledToFill()
                        .overlay(LinearGradient(colors: [Color.black.opacity(0.18), Color.black.opacity(0.75)], startPoint: .top, endPoint: .bottom))
                case .failure(_):
                    fallbackCover
                case .empty:
                    fallbackCover.overlay(ProgressView().tint(Lx.gold))
                @unknown default:
                    fallbackCover
                }
            }
        } else {
            fallbackCover
        }
    }

    private var fallbackCover: some View {
        LinearGradient(colors: [Color.black.opacity(0.85), Color.black.opacity(0.55)], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}
