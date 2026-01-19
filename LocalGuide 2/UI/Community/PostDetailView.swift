import SwiftUI

struct PostDetailView: View {
    @EnvironmentObject var appState: AppState
    @State var post: FeedPost
    @State private var comments: [FeedComment] = []
    @State private var newComment = ""
    @State private var isLoading = false
    @State private var showReport = false
    @State private var reportTarget: (FeedReport.TargetType, String)? = nil

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    LuxuryCard {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text(post.title).font(.title3.bold()).foregroundStyle(.white)
                                Spacer()
                                Menu {
                                    Button("Report post") {
                                        reportTarget = (.post, post.id)
                                        showReport = true
                                    }
                                } label: {
                                    Image(systemName: "ellipsis.circle").foregroundStyle(.white.opacity(0.7))
                                }
                                .buttonStyle(.plain)
                            }
                            Text(post.text)
                                .foregroundStyle(.white.opacity(0.9))
                            HStack(spacing: 12) {
                                Button {
                                    Task { await toggleLike() }
                                } label: {
                                    Label("Like", systemImage: "heart")
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(Lx.gold)
                                Spacer()
                                Text(post.createdAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.6))
                            }
                        }
                    }

                    Text("Comments")
                        .font(.headline)
                        .foregroundStyle(.white)

                    ForEach(comments) { c in
                        LuxuryCard {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(c.authorName ?? "User")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.white)
                                    Spacer()
                                    Menu {
                                        Button("Report comment") {
                                            reportTarget = (.comment, c.id)
                                            showReport = true
                                        }
                                    } label: {
                                        Image(systemName: "ellipsis").foregroundStyle(.white.opacity(0.6))
                                    }
                                    .buttonStyle(.plain)
                                }
                                Text(c.text)
                                    .foregroundStyle(.white.opacity(0.85))
                                    .font(.subheadline)
                                HStack {
                                    Label("\(c.likeCount)", systemImage: "heart")
                                    Spacer()
                                    Text(c.createdAt.formatted(date: .abbreviated, time: .shortened))
                                }
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.6))
                            }
                        }
                    }

                    LuxuryCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Add a comment")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            TextEditor(text: $newComment)
                                .frame(minHeight: 90)
                                .scrollContentBackground(.hidden)
                                .padding(10)
                                .background(Color.white.opacity(0.06))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            Button {
                                Task { await postComment() }
                            } label: {
                                Text("Send")
                            }
                            .buttonStyle(LuxuryPrimaryButtonStyle())
                            .disabled(newComment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                }
                .padding(18)
            }
        }
        .navigationTitle("Post")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .sheet(isPresented: $showReport) {
            if let target = reportTarget {
                ReportSheetView(targetType: target.0, targetId: target.1, postId: post.id)
                    .environmentObject(appState)
            }
        }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            comments = try await FirestoreService.shared.listComments(postId: post.id)
        } catch { }
    }

    private func toggleLike() async {
        do {
            try await FirestoreService.shared.likePost(postId: post.id, delta: 1)
            post.likeCount += 1
        } catch { }
    }

    private func postComment() async {
        guard let uid = appState.session.firebaseUser?.uid else { return }
        let text = newComment.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        newComment = ""
        do {
            let user = appState.session.currentUser
            let c = FeedComment(
                id: UUID().uuidString,
                postId: post.id,
                authorId: uid,
                authorName: user?.fullName,
                text: text,
                likeCount: 0,
                reportCount: 0,
                isHidden: false,
                createdAt: Date()
            )
            try await FirestoreService.shared.createComment(c)
            comments.append(c)
            post.commentCount += 1
        } catch { }
    }
}
