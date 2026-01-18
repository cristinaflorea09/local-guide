import SwiftUI

enum ChatMode { case traveler, seller }

struct ChatsListView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var chatUnread: ChatUnreadService
    let mode: ChatMode

    @State private var threads: [ChatThread] = []
    @State private var isLoading = false
    @StateObject private var directory = ProfileDirectory()

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
                                NavigationLink {
                                    ChatView(thread: t)
                                } label: {
                                    LuxuryCard {
                                        HStack {
                                            ZStack {
                                                AvatarView(url: avatarURL(for: t), size: 42)
                                            }
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(title(for: t))
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
        }
    }

    private func load() async {
        guard let uid = appState.session.firebaseUser?.uid else { return }
        isLoading = true
        do {
            threads = (mode == .traveler)
                ? try await FirestoreService.shared.getChatThreadsForUser(userId: uid)
                : try await FirestoreService.shared.getChatThreadsForGuide(guideId: uid)
        } catch {
            threads = []
        }
        await prefetchCounterparts()
        isLoading = false
    }


    private func prefetchCounterparts() async {
        for t in threads {
            switch mode {
            case .traveler:
                await directory.loadGuideIfNeeded(t.guideId)
            case .seller:
                await directory.loadUserIfNeeded(t.userId)
            }
        }
    }

    private func title(for thread: ChatThread) -> String {
        switch mode {
        case .traveler:
            return directory.guide(thread.guideId)?.displayName ?? "Guide"
        case .seller:
            return directory.user(thread.userId)?.email ?? "Traveler"
        }
    }

    private func avatarURL(for thread: ChatThread) -> String? {
        switch mode {
        case .traveler:
            return directory.guide(thread.guideId)?.photoURL
        case .seller:
            return nil
        }
    }
}

