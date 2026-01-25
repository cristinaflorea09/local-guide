import SwiftUI

enum ChatMode { case traveler, seller }

struct ChatsListView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var chatUnread: ChatUnreadService
    let mode: ChatMode

    @State private var threads: [ChatThread] = []
    @State private var isLoading = false
    @StateObject private var directory = ProfileDirectory()

    struct ThreadDisplay: Equatable {
        var title: String
        var avatarURL: String?
    }

    @State private var displayCache: [String: ThreadDisplay] = [:] // key: thread.id
    @State private var selectedThread: ChatThread?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Chat")
                            .font(.largeTitle.bold())
                            .foregroundStyle(.white)
                            .padding(.top, 8)

                        if isLoading { ProgressView("Loading…").tint(Lx.gold) }

                        LazyVStack(spacing: 12) {
                            ForEach(threads) { t in
                                Button {
                                    selectedThread = t
                                } label: {
                                    LuxuryCard {
                                        HStack {
                                            ZStack {
                                                AvatarView(url: displayCache[t.id]?.avatarURL, size: 42)
                                            }
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(displayCache[t.id]?.title ?? "")
                                                    .font(.headline)
                                                    .lineLimit(1)
                                                Text(t.updatedAt.formatted(date: .abbreviated, time: .shortened))
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                            Spacer()
                                            if let uid = appState.session.firebaseUser?.uid,
                                               chatUnread.isUnread(thread: t, currentUid: uid) {
                                                Circle()
                                                    .fill(Lx.gold)
                                                    .frame(width: 10, height: 10)
                                                    .padding(.trailing, 6)
                                            }
                                            Image(systemName: "chevron.right").foregroundStyle(.secondary)
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        if !isLoading && threads.isEmpty {
                            Text("No chats yet.")
                                .foregroundStyle(.white.opacity(0.7))
                                .padding(.top, 8)
                        }
                    }
                    .padding(18)
                }
            }
            .toolbar {
            }
            .task { await load() }
            .onReceive(Timer.publish(every: 20, on: .main, in: .common).autoconnect()) { _ in
                Task { await load() }
            }
            .fullScreenCover(item: $selectedThread) { thread in
                NavigationStack {
                    ChatView(thread: thread)
                        .toolbar {
                            ToolbarItem(placement: .topBarLeading) {
                                Button {
                                    selectedThread = nil
                                } label: {
                                    Image(systemName: "chevron.left")
                                }
                            }
                        }
                }
            }
        }
    }

    private func load() async {
        guard let uid = appState.session.firebaseUser?.uid else { return }
        guard let email = appState.session.firebaseUser?.email else { return }
        isLoading = true
        do {
            threads = (mode == .traveler)
                ? try await FirestoreService.shared.getChatThreadsForUser(userId: uid)
                : try await FirestoreService.shared.getChatThreadsForGuide(email: email)

        } catch {
            threads = []
        }
        await prefetchCounterparts()
        await buildDisplayCache()
        isLoading = false
    }

    private func prefetchCounterparts() async {
        for t in threads {
            switch mode {
            case .traveler:
                await directory.loadGuideIfNeeded(t.email)
            case .seller:
                await directory.loadUserIfNeeded(t.userId)
            }
        }
    }

    private func buildDisplayCache() async {
        var map: [String: ThreadDisplay] = [:]
        for t in threads {
            switch mode {
            case .traveler:
                await directory.loadGuideIfNeeded(t.email)
                let guide = directory.guide(t.email)
                var host: HostProfile? = nil
                if guide == nil {
                    await directory.loadHostIfNeeded(t.email)
                    host = directory.host(t.email)
                }
                let title = guide?.displayName ?? host?.brandName ?? (guide == nil ? "Host" : "Guide")
                let avatar = guide?.photoURL ?? host?.photoURL
                map[t.id] = ThreadDisplay(title: title, avatarURL: avatar)
            case .seller:
                await directory.loadUserIfNeeded(t.userId)
                let u = directory.user(t.userId)
                let title: String = {
                    if let name = u?.fullName, !name.isEmpty { return name }
                    return u?.email ?? "Traveler"
                }()
                let avatar = u?.photoURL
                map[t.id] = ThreadDisplay(title: title, avatarURL: avatar)
            }
        }
        await MainActor.run {
            self.displayCache = map
        }
    }
}

