import Foundation
import FirebaseFirestore

/// Tracks unread chat threads for the current user and exposes a simple unread count.
///
/// Implementation is client-side and backward compatible:
/// - Uses `ChatThread.lastSenderId` when available.
/// - Stores per-thread last-read timestamps in `UserDefaults`.
final class ChatUnreadService: ObservableObject {
    static let shared = ChatUnreadService()

    @Published private(set) var unreadCount: Int = 0

    private var listener: ListenerRegistration?
    private let defaults = UserDefaults.standard

    private init() {}

    func stop() {
        listener?.remove()
        listener = nil
        //unreadCount = 0
    }

    func markRead(threadId: String) {
        defaults.set(Date().timeIntervalSince1970, forKey: key(for: threadId))
        // Recompute quickly; avoids waiting for the next snapshot.
        recomputeFromDefaultsOnly()
    }

    /// Starts listening to relevant threads for the logged-in user.
    /// Call this whenever the session user changes.
    func start(role: UserRole, uid: String) {
        stop()

        let db = FirebaseManager.shared.db
        let threads = db.collection("threads")
        let query: Query
        switch role {
        case .traveler:
            query = threads.whereField("userId", isEqualTo: uid)
        case .guide, .host:
            // For sellers we treat both roles the same: threads store `guideId`.
            query = threads.whereField("guideId", isEqualTo: uid)
        case .admin:
            // Admins don't need chat unread tracking.
            return
        }

        listener = query.addSnapshotListener { [weak self] snap, _ in
            guard let self else { return }
            let docs = snap?.documents ?? []
            let threads: [ChatThread] = docs.compactMap { try? $0.data(as: ChatThread.self) }

            var count = 0
            for t in threads {
                if self.isUnread(thread: t, currentUid: uid) {
                    count += 1
                }
            }
            self.unreadCount = count
        }
    }

    func isUnread(thread: ChatThread, currentUid: String) -> Bool {
        // If we know who sent the last message and it's the current user, it's not unread.
        if let lastSender = thread.lastSenderId, lastSender == currentUid {
            return false
        }
        let lastRead = defaults.double(forKey: key(for: thread.id))
        if lastRead <= 0 {
            // Never opened: treat as unread only if there's a lastMessage.
            return (thread.lastMessage?.isEmpty == false)
        }
        return thread.updatedAt.timeIntervalSince1970 > lastRead
    }

    private func key(for threadId: String) -> String {
        "chat_last_read_\(threadId)"
    }

    private func recomputeFromDefaultsOnly() {
        // Best-effort: keep current unreadCount from stale snapshot until next update.
        // We can't recompute without the current thread list.
        // So we just decrement conservatively.
        if unreadCount > 0 { unreadCount -= 1 }
    }
}
