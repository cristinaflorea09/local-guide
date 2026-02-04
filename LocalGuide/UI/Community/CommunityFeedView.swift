import SwiftUI

struct CommunityFeedView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.openURL) private var openURL
    @State private var posts: [FeedPost] = []
    @State private var isLoading = false
    @State private var showComposer = false
    @State private var selectedPost: FeedPost?
    @State private var blockError: String?

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
                            NavigationLink {
                                CommunityGuidelinesView()
                            } label: {
                                Image(systemName: "info.circle")
                                    .foregroundStyle(Lx.gold)
                                    .font(.title3)
                            }
                            .buttonStyle(.plain)
                            Button {
                                showComposer = true
                            } label: {
                                Image(systemName: "square.and.pencil")
                                    .foregroundStyle(Lx.gold)
                                    .font(.title3)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("community_compose_button")
                        }

                        if isLoading { ProgressView().tint(Lx.gold) }

                        ForEach(visiblePosts) { post in
                            FeedPostCard(
                                post: post,
                                canBlock: canBlock(post.authorId),
                                isBlocked: isBlocked(post.authorId),
                                onToggleBlock: {
                                    Task { await toggleBlock(post.authorId) }
                                }
                            )
                            .onTapGesture { selectedPost = post }
                        }

                        LuxuryCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Need help?")
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                Text("Contact support about community reports or safety issues.")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.7))
                                Button("Contact support") {
                                    contactSupport()
                                }
                                .buttonStyle(LuxurySecondaryButtonStyle())
                            }
                        }
                        if let blockError {
                            Text(blockError)
                                .foregroundStyle(.red)
                                .font(.caption)
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
            .fullScreenCover(item: $selectedPost) { post in
                NavigationStack {
                    PostDetailView(post: post) { updated in
                        updatePost(updated)
                        if selectedPost?.id == updated.id {
                            selectedPost = updated
                        }
                    }
                        .environmentObject(appState)
                        .toolbar {
                            ToolbarItem(placement: .topBarLeading) {
                                Button {
                                    selectedPost = nil
                                } label: {
                                    Image(systemName: "chevron.left")
                                }
                            }
                        }
                }
            }
        }
    }

    private var blockedSet: Set<String> {
        let ids = appState.session.currentUser?.blockedUserIds ?? []
        return Set(ids.map { $0.lowercased() })
    }

    private var visiblePosts: [FeedPost] {
        posts.filter { !isBlocked($0.authorId) }
    }

    private func isBlocked(_ authorId: String) -> Bool {
        blockedSet.contains(authorId.lowercased())
    }

    private func canBlock(_ authorId: String) -> Bool {
        let uid = appState.session.firebaseUser?.uid.lowercased()
        let email = appState.session.firebaseUser?.email?.lowercased()
        let userId = appState.session.currentUser?.id.lowercased()
        let author = authorId.lowercased()
        return ![uid, email, userId].compactMap { $0 }.contains(author)
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

    private func toggleBlock(_ authorId: String) async {
        guard var user = appState.session.currentUser else { return }
        blockError = nil
        do {
            if isBlocked(authorId) {
                try await FirestoreService.shared.unblockUser(docId: user.id, blockedId: authorId)
                var ids = user.blockedUserIds ?? []
                ids.removeAll { $0.lowercased() == authorId.lowercased() }
                user.blockedUserIds = ids
            } else {
                try await FirestoreService.shared.blockUser(docId: user.id, blockedId: authorId)
                var ids = user.blockedUserIds ?? []
                ids.append(authorId)
                user.blockedUserIds = ids
            }
            appState.session.currentUser = user
        } catch {
            blockError = error.localizedDescription
        }
    }

    private func contactSupport() {
        let email = AppConfig.supportEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !email.isEmpty, let url = URL(string: "mailto:\(email)") else { return }
        openURL(url)
    }

    private func updatePost(_ updated: FeedPost) {
        if let idx = posts.firstIndex(where: { $0.id == updated.id }) {
            posts[idx] = updated
        }
    }
}

private struct FeedPostCard: View {
    let post: FeedPost
    var canBlock: Bool = false
    var isBlocked: Bool = false
    var onToggleBlock: (() -> Void)? = nil

    var body: some View {
        LuxuryCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text(post.title)
                        .font(.headline)
                        .foregroundStyle(.white)
                    Spacer()
                    Text(post.type.rawValue.uppercased())
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Lx.gold)
                    if canBlock {
                        Menu {
                            Button(isBlocked ? "Unblock user" : "Block user") {
                                onToggleBlock?()
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .foregroundStyle(.white.opacity(0.7))
                        }
                        .buttonStyle(.plain)
                    }
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
