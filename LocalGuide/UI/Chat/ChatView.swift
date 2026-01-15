import SwiftUI
import FirebaseFirestore

struct ChatView: View {
    @EnvironmentObject var appState: AppState
    let thread: ChatThread

    @StateObject private var directory = ProfileDirectory()

    @State private var messages: [ChatMessage] = []
    @State private var text = ""
    @State private var listener: ListenerRegistration?
    @State private var counterpartName: String = "Chat"
    @State private var counterpartPhotoURL: String?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 10) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(messages) { m in
                                let isMe = (m.senderId == appState.session.firebaseUser?.uid)
                                HStack {
                                    if isMe { Spacer() }
                                    Text(m.text)
                                        .foregroundStyle(isMe ? .black : .white)
                                        .padding(.vertical, 10)
                                        .padding(.horizontal, 12)
                                        .background(
                                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                                .fill(isMe ? Lx.gold : Color.white.opacity(0.14))
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                                .stroke(isMe ? Color.clear : Lx.gold.opacity(0.20), lineWidth: 1)
                                        )
                                        .frame(maxWidth: 260, alignment: isMe ? .trailing : .leading)
                                    if !isMe { Spacer() }
                                }
                                .padding(.horizontal, 18)
                                .id(m.id)
                            }
                        }
                        .padding(.vertical, 14)
                    }
                    .onChange(of: messages.count) { _ in
                        if let last = messages.last {
                            withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                        }
                    }
                }

                LuxuryCard {
                    HStack(spacing: 10) {
                        TextField("Message…", text: $text)
                            .foregroundStyle(.primary)
                        Button { Task { await send() } } label: {
                            Image(systemName: "paperplane.fill")
                                .foregroundStyle(.black)
                                .padding(10)
                                .background(Lx.gold)
                                .clipShape(Circle())
                        }
                        .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 10)
            }
        }
        .navigationTitle(counterpartName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                AvatarView(url: counterpartPhotoURL, size: 28)
            }
        }
        .onAppear { Task { await loadCounterpart() }; startListening() }
        .onDisappear { listener?.remove() }
    }

    private func startListening() {
        listener?.remove()
        listener = FirestoreService.shared.listenToMessages(threadId: thread.id) { msgs in
            self.messages = msgs
        }
    }

    private func send() async {
        guard let uid = appState.session.firebaseUser?.uid else { return }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        text = ""
        do {
            try await FirestoreService.shared.sendMessage(
                threadId: thread.id,
                senderId: uid,
                text: trimmed,
                userId: thread.userId,
                guideId: thread.guideId,
                tourId: thread.tourId
            )
        } catch { }
    }


    private func loadCounterpart() async {
        // If I'm the user, show guide. If I'm the guide, show traveler.
        if let myId = appState.session.firebaseUser?.uid, myId == thread.userId {
            await directory.loadGuideIfNeeded(thread.guideId)
            let g = directory.guide(thread.guideId)
            await MainActor.run {
                self.counterpartName = g?.displayName ?? "Guide"
                self.counterpartPhotoURL = g?.photoURL
            }
        } else {
            await directory.loadUserIfNeeded(thread.userId)
            let u = directory.user(thread.userId)
            await MainActor.run {
                self.counterpartName = u?.email ?? "Traveler"
                self.counterpartPhotoURL = nil
            }
        }
    }
}
