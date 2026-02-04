import SwiftUI

struct AvatarView: View {
    let url: String?
    var size: CGFloat = 34

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.10))
                .frame(width: size, height: size)
                .overlay(Circle().stroke(Lx.gold.opacity(0.20), lineWidth: 1))

            if let url, let u = URL(string: url) {
                CachedAsyncImage(url: u) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Image(systemName: "person.fill").foregroundStyle(Lx.gold)
                }
                .frame(width: size, height: size)
                .clipShape(Circle())
            } else {
                Image(systemName: "person.fill").foregroundStyle(Lx.gold)
            }
        }
    }
}
