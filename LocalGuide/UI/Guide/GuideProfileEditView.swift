import SwiftUI

struct GuideProfileEditView: View {
    @EnvironmentObject var appState: AppState

    @State private var displayName = ""
    @State private var city = ""
    @State private var languages = ""
    @State private var bio = ""

    @State private var profileImage: UIImage?
    @State private var remotePhotoURL: String?

    @State private var isLoading = false
    @State private var message: String?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Edit Profile")
                        .font(.largeTitle.bold())
                        .foregroundStyle(.white)
                        .padding(.top, 8)

                    LuxuryCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Profile photo")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)

                            ImagePicker(image: $profileImage)

                            HStack {
                                Spacer()
                                avatarView
                                Spacer()
                            }

                            Divider().opacity(0.15)

                            LuxuryTextField(title: "Display name", text: $displayName)
                            LuxuryTextField(title: "City", text: $city)
                            LuxuryTextField(title: "Languages (comma separated)", text: $languages)
                            LuxuryTextField(title: "Bio", text: $bio)
                        }
                    }

                    if let message {
                        Text(message)
                            .foregroundStyle(.white.opacity(0.75))
                    }

                    Button {
                        Haptics.medium()
                        Task { await save() }
                    } label: {
                        if isLoading { ProgressView().tint(.black) } else { Text("Save changes") }
                    }
                    .buttonStyle(LuxuryPrimaryButtonStyle())
                    .disabled(isLoading || displayName.isEmpty || city.isEmpty)

                    Spacer(minLength: 12)
                }
                .padding(18)
            }
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    @ViewBuilder
    private var avatarView: some View {
        let size: CGFloat = 96
        ZStack {
            Circle().fill(Color.white.opacity(0.10)).frame(width: size, height: size)
                .overlay(Circle().stroke(Lx.gold.opacity(0.22), lineWidth: 1))

            if let img = profileImage {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else if let url = remotePhotoURL, let u = URL(string: url) {
                AsyncImage(url: u) { phase in
                    switch phase {
                    case .success(let img):
                        img.resizable().scaledToFill()
                    default:
                        Image(systemName: "person.fill").foregroundStyle(Lx.gold)
                    }
                }
                .frame(width: size, height: size)
                .clipShape(Circle())
            } else {
                Image(systemName: "person.fill").foregroundStyle(Lx.gold)
            }
        }
    }

    private func load() async {
        guard let uid = appState.session.firebaseUser?.uid else { return }
        isLoading = true
        message = nil
        do {
            let p = try await FirestoreService.shared.getGuideProfile(guideId: uid)
            displayName = p.displayName
            city = p.city
            languages = p.languages.joined(separator: ", ")
            bio = p.bio
            remotePhotoURL = p.photoURL
        } catch {
            message = error.localizedDescription
        }
        isLoading = false
    }

    private func save() async {
        guard let uid = appState.session.firebaseUser?.uid else { return }
        isLoading = true
        message = nil

        do {
            var photoURL = remotePhotoURL
            if let profileImage {
                photoURL = try await StorageService.shared.uploadGuidePhoto(uid: uid, image: profileImage)
            }

            let langs = languages
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

            // Keep rating fields as-is by fetching existing
            let existing = try await FirestoreService.shared.getGuideProfile(guideId: uid)

            let updated = GuideProfile(
                id: uid,
                displayName: displayName,
                city: city,
                languages: langs.isEmpty ? ["English"] : langs,
                bio: bio,
                photoURL: photoURL,
                ratingAvg: existing.ratingAvg,
                ratingCount: existing.ratingCount,
                createdAt: existing.createdAt
            )
            try await FirestoreService.shared.updateGuideProfile(updated)
            remotePhotoURL = photoURL
            profileImage = nil
            Haptics.success()
            message = "Saved ✅"
        } catch {
            message = error.localizedDescription
        }

        isLoading = false
    }
}
