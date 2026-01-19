import SwiftUI

struct CommunityFeedView: View {
    @EnvironmentObject var appState: AppState
    @State private var posts: [FeedPost] = []
    @State private var isLoading = false
    @State private var showComposer = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Community")
                                .font(.largeTitle.bold())
                                .foregroundStyle(.white)
                            Spacer()
                            Button {
                                showComposer = true
                            } label: {
                                Image(systemName: "square.and.pencil")
                                    .foregroundStyle(Lx.gold)
                                    .font(.title3)
                            }
                            .buttonStyle(.plain)
                        }

                        if isLoading { ProgressView().tint(Lx.gold) }

                        ForEach(posts) { post in
                            NavigationLink {
                                PostDetailView(post: post)
                            } label: {
                                FeedPostCard(post: post)
                            }
                            .buttonStyle(.plain)
                        }
                        Spacer(minLength: 12)
                    }
                    .padding(18)
                }
            }
            .task { await reload() }
            .refreshable { await reload() }
            .sheet(isPresented: $showComposer) {
                PostComposerView(onPosted: { Task { await reload() } })
                    .environmentObject(appState)
            }
        }
    }

    private func reload() async {
        isLoading = true
        defer { isLoading = false }
        do {
            posts = try await FirestoreService.shared.listPosts(limit: 60)
        } catch {
            posts = []
        }
    }
}

private struct FeedPostCard: View {
    let post: FeedPost
    var body: some View {
        LuxuryCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(post.title)
                        .font(.headline)
                        .foregroundStyle(.white)
                    Spacer()
                    Text(post.type.rawValue.uppercased())
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Lx.gold)
                }
                Text(post.text)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(3)
                HStack(spacing: 12) {
                    Label("\(post.likeCount)", systemImage: "heart")
                    Label("\(post.commentCount)", systemImage: "bubble.right")
                    if let city = post.city, !city.isEmpty {
                        Label(city, systemImage: "mappin.and.ellipse")
                    }
                }
                .font(.caption)
                .foregroundStyle(.white.opacity(0.7))
            }
        }
    }
}
