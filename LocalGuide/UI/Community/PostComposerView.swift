import SwiftUI

struct PostComposerView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    var onPosted: (() -> Void)?

    @State private var type: FeedPost.PostType = .tip
    @State private var title = ""
    @State private var text = ""
    @State private var city = ""
    @State private var isLoading = false
    @State private var errorText: String? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("New post")
                            .font(.largeTitle.bold())
                            .foregroundStyle(.white)

                        LuxuryCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Picker("Type", selection: $type) {
                                    ForEach(FeedPost.PostType.allCases, id: \.self) { t in
                                        Text(t.rawValue).tag(t)
                                    }
                                }
                                .pickerStyle(.segmented)

                                LuxuryTextField(title: "Title", text: $title, identifier: "post_title")
                                LuxuryTextField(title: "City (optional)", text: $city, identifier: "post_city")

                                Text("Message")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                TextEditor(text: $text)
                                    .frame(minHeight: 140)
                                    .scrollContentBackground(.hidden)
                                    .padding(10)
                                    .background(Color.white.opacity(0.06))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .accessibilityIdentifier("post_body")
                            }
                        }

                        if let errorText {
                            Text(errorText)
                                .foregroundStyle(.red)
                        }

                        Button {
                            Task { await submit() }
                        } label: {
                            if isLoading { ProgressView().tint(.black) } else { Text("Post") }
                        }
                        .buttonStyle(LuxuryPrimaryButtonStyle())
                        .disabled(isLoading || title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .accessibilityIdentifier("post_submit")
                    }
                    .padding(18)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(.white)
                }
            }
        }
        .onAppear {
            guard AppEnvironment.uiTestAutofill else { return }
            if let value = AppEnvironment.uiTestPostTitle { title = value }
            if let value = AppEnvironment.uiTestPostBody { text = value }
        }
    }

    private func submit() async {
        guard let uid = appState.session.firebaseUser?.uid else { return }
        isLoading = true
        errorText = nil
        defer { isLoading = false }

        do {
            let user = appState.session.currentUser
            let post = FeedPost(
                id: UUID().uuidString,
                authorId: uid,
                authorName: user?.fullName,
                authorRole: user?.role.rawValue,
                type: type,
                title: title,
                text: text,
                city: city.isEmpty ? nil : city,
                photoURL: nil,
                likeCount: 0,
                commentCount: 0,
                reportCount: 0,
                isHidden: false,
                createdAt: Date()
            )
            try await FirestoreService.shared.createPost(post)
            onPosted?()
            dismiss()
        } catch {
            errorText = error.localizedDescription
        }
    }
}
