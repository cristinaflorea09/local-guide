import SwiftUI

struct PostDetailView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.openURL) private var openURL
    @State var post: FeedPost
    var onPostUpdated: ((FeedPost) -> Void)?
    @State private var comments: [FeedComment] = []
    @State private var newComment = ""
    @State private var isLoading = false
    @State private var showReport = false
    @State private var reportTarget: (FeedReport.TargetType, String)? = nil
    @State private var isLiked = false
    @State private var editTarget: FeedComment?
    @State private var editText = ""
    @State private var deleteTarget: FeedComment?
    @State private var showDeleteConfirm = false
    @State private var blockError: String?

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
                                    Button("Report abuse by email") {
                                        reportAbuseEmail(postId: post.id, commentId: nil)
                                    }
                                    if canBlock(post.authorId) {
                                        Button(isBlocked(post.authorId) ? "Unblock user" : "Block user") {
                                            Task { await toggleBlock(post.authorId) }
                                        }
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
                                    Task {
                                        if isLiked {
                                            await toggleUnlike()
                                        } else {
                                            await toggleLike()
                                        }
                                    }
                                } label: {
                                    Label(isLiked ? "Liked" : "Like", systemImage: isLiked ? "heart.fill" : "heart")
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(Lx.gold)
                                .accessibilityIdentifier("post_like_button")
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

                    ForEach(visibleComments) { c in
                        LuxuryCard {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(c.authorName ?? "User")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.white)
                                    Spacer()
                                    Menu {
                                        if canModifyComment(c) {
                                            Button("Edit comment") {
                                                editText = c.text
                                                editTarget = c
                                            }
                                            Button("Delete comment", role: .destructive) {
                                                deleteTarget = c
                                                showDeleteConfirm = true
                                            }
                                        }
                                        Button("Report comment") {
                                            reportTarget = (.comment, c.id)
                                            showReport = true
                                        }
                                        Button("Report abuse by email") {
                                            reportAbuseEmail(postId: post.id, commentId: c.id)
                                        }
                                        if canBlock(c.authorId) {
                                            Button(isBlocked(c.authorId) ? "Unblock user" : "Block user") {
                                                Task { await toggleBlock(c.authorId) }
                                            }
                                        }
                                    } label: {
                                        Image(systemName: "ellipsis").foregroundStyle(.white.opacity(0.6))
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityIdentifier("comment_menu")
                                }
                                Text(c.text)
                                    .foregroundStyle(.white.opacity(0.85))
                                    .font(.subheadline)
                                HStack {
                                    Button {
                                        Task { await toggleCommentLike(c) }
                                    } label: {
                                        Label("\(c.likeCount)", systemImage: isCommentLiked(c) ? "heart.fill" : "heart")
                                    }
                                    .buttonStyle(.plain)
                                    .foregroundStyle(Lx.gold)
                                    .accessibilityIdentifier("comment_like_button")
                                    Spacer()
                                    Text(c.createdAt.formatted(date: .abbreviated, time: .shortened))
                                }
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.6))
                            }
                        }
                    }

                    if let blockError {
                        Text(blockError)
                            .foregroundStyle(.red)
                            .font(.caption)
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
                                .accessibilityIdentifier("comment_input")
                            Button {
                                Task { await postComment() }
                            } label: {
                                Text("Send")
                            }
                            .buttonStyle(LuxuryPrimaryButtonStyle())
                            .disabled(newComment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            .accessibilityIdentifier("comment_send")
                        }
                    }
                }
                .padding(18)
            }
        }
        .navigationTitle("Post")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .onAppear {
            if AppEnvironment.uiTestAutofill, let value = AppEnvironment.uiTestComment {
                newComment = value
            }
        }
        .sheet(isPresented: $showReport) {
            if let target = reportTarget {
                ReportSheetView(targetType: target.0, targetId: target.1, postId: post.id)
                    .environmentObject(appState)
            }
        }
        .sheet(item: $editTarget) { comment in
            NavigationStack {
                ZStack {
                    Color.black.ignoresSafeArea()
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Edit comment")
                            .font(.headline)
                            .foregroundStyle(.white)
                        TextEditor(text: $editText)
                            .frame(minHeight: 120)
                            .scrollContentBackground(.hidden)
                            .padding(10)
                            .background(Color.white.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .accessibilityIdentifier("comment_edit_input")
                        Button("Save") {
                            Task { await saveEditedComment(comment) }
                        }
                        .buttonStyle(LuxuryPrimaryButtonStyle())
                        .disabled(editText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .accessibilityIdentifier("comment_edit_save")
                        Spacer()
                    }
                    .padding(18)
                }
                .navigationTitle("Edit")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Close") { editTarget = nil }
                            .foregroundStyle(.white)
                    }
                }
            }
        }
        .confirmationDialog("Delete this comment?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let target = deleteTarget {
                    Task { await deleteComment(target) }
                }
            }
            Button("Cancel", role: .cancel) { deleteTarget = nil }
        }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            comments = try await FirestoreService.shared.listComments(postId: post.id)
            post.commentCount = comments.count
        } catch { }
        if let uid = appState.session.firebaseUser?.uid {
            isLiked = post.likedBy?.contains(uid) == true
        }
        onPostUpdated?(post)
    }

    private func toggleLike() async {
        guard let uid = appState.session.firebaseUser?.uid else { return }
        if isLiked { return } // one like only
        do {
            let didLike = try await FirestoreService.shared.likePost(postId: post.id, userId: uid)
            if didLike {
                post.likeCount += 1
                if post.likedBy == nil { post.likedBy = [] }
                post.likedBy?.append(uid)
                isLiked = true
                Haptics.success()
                onPostUpdated?(post)
            }
        } catch {
            // no-op
        }
    }

    private func toggleUnlike() async {
        guard let uid = appState.session.firebaseUser?.uid else { return }
        guard isLiked else { return }
        do {
            let didUnlike = try await FirestoreService.shared.unlikePost(postId: post.id, userId: uid)
            if didUnlike {
                post.likeCount = max(0, post.likeCount - 1)
                if var arr = post.likedBy {
                    arr.removeAll { $0 == uid }
                    post.likedBy = arr
                }
                isLiked = false
                Haptics.light()
                onPostUpdated?(post)
            }
        } catch {
            // no-op on failure
        }
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
            onPostUpdated?(post)
        } catch { }
    }

    private func isCommentLiked(_ comment: FeedComment) -> Bool {
        guard let uid = appState.session.firebaseUser?.uid else { return false }
        return comment.likedBy?.contains(uid) == true
    }

    private func canModifyComment(_ comment: FeedComment) -> Bool {
        let uid = appState.session.firebaseUser?.uid
        let email = appState.session.firebaseUser?.email?.lowercased()
        let userId = appState.session.currentUser?.id.lowercased()
        let author = comment.authorId.lowercased()
        return [uid, email, userId].compactMap { $0?.lowercased() }.contains(author)
    }

    private var blockedSet: Set<String> {
        let ids = appState.session.currentUser?.blockedUserIds ?? []
        return Set(ids.map { $0.lowercased() })
    }

    private var visibleComments: [FeedComment] {
        comments.filter { !isBlocked($0.authorId) }
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

    private func toggleCommentLike(_ comment: FeedComment) async {
        guard let uid = appState.session.firebaseUser?.uid else { return }
        if isCommentLiked(comment) {
            do {
                let didUnlike = try await FirestoreService.shared.unlikeComment(commentId: comment.id, userId: uid)
                if didUnlike {
                    updateComment(comment.id) { existing in
                        existing.likeCount = max(0, existing.likeCount - 1)
                        if var likedBy = existing.likedBy {
                            likedBy.removeAll { $0 == uid }
                            existing.likedBy = likedBy
                        }
                    }
                    Haptics.light()
                }
            } catch { }
        } else {
            do {
                let didLike = try await FirestoreService.shared.likeComment(commentId: comment.id, userId: uid)
                if didLike {
                    updateComment(comment.id) { existing in
                        existing.likeCount += 1
                        if existing.likedBy == nil { existing.likedBy = [] }
                        existing.likedBy?.append(uid)
                    }
                    Haptics.success()
                }
            } catch { }
        }
    }

    private func saveEditedComment(_ comment: FeedComment) async {
        let text = editText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        do {
            try await FirestoreService.shared.updateComment(commentId: comment.id, fields: ["text": text])
            updateComment(comment.id) { existing in
                existing.text = text
            }
            editTarget = nil
            Haptics.success()
        } catch { }
    }

    private func deleteComment(_ comment: FeedComment) async {
        do {
            try await FirestoreService.shared.deleteComment(commentId: comment.id, postId: post.id)
            comments.removeAll { $0.id == comment.id }
            post.commentCount = max(0, post.commentCount - 1)
            onPostUpdated?(post)
            deleteTarget = nil
            showDeleteConfirm = false
            Haptics.success()
        } catch { }
    }

    private func updateComment(_ id: String, mutate: (inout FeedComment) -> Void) {
        guard let idx = comments.firstIndex(where: { $0.id == id }) else { return }
        var updated = comments[idx]
        mutate(&updated)
        comments[idx] = updated
    }

    private func reportAbuseEmail(postId: String, commentId: String?) {
        let email = AppConfig.supportEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !email.isEmpty else { return }
        let subject = "Report abuse: post \(postId)"
        var body = "Post ID: \(postId)\n"
        if let commentId { body += "Comment ID: \(commentId)\n" }
        body += "\nPlease describe the issue:\n"
        let subjectEncoded = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let bodyEncoded = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        guard let url = URL(string: "mailto:\(email)?subject=\(subjectEncoded)&body=\(bodyEncoded)") else { return }
        openURL(url)
    }
}
