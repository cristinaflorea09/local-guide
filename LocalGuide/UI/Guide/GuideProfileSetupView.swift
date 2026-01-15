import SwiftUI

struct GuideProfileSetupView: View {
    @EnvironmentObject var appState: AppState

    @State private var displayName = ""
    @State private var city = ""
    @State private var languages = "English"
    @State private var bio = ""
    @State private var profileImage: UIImage?

    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Guide Profile")
                        .font(.largeTitle.bold())
                        .foregroundStyle(.white)
                        .padding(.top, 8)

                    LuxuryCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Profile photo")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)

                            ImagePicker(image: $profileImage)

                            if let img = profileImage {
                                HStack {
                                    Spacer()
                                    Image(uiImage: img)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 92, height: 92)
                                        .clipShape(Circle())
                                        .overlay(Circle().stroke(Lx.gold.opacity(0.22), lineWidth: 1))
                                    Spacer()
                                }
                            }

                            Divider().opacity(0.15)

                            LuxuryTextField(title: "Display name", text: $displayName)
                            LuxuryTextField(title: "City", text: $city)
                            LuxuryTextField(title: "Languages (comma separated)", text: $languages)
                            LuxuryTextField(title: "Bio", text: $bio)

                            Text("Tip: a polished profile increases bookings.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if let errorMessage {
                        Text(errorMessage).foregroundStyle(.red)
                    }

                    Button {
                        Haptics.medium()
                        Task { await save() }
                    } label: {
                        if isLoading { ProgressView().tint(.black) } else { Text("Save profile") }
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
    }

    private func save() async {
        guard let uid = appState.session.firebaseUser?.uid else { return }
        isLoading = true
        errorMessage = nil

        do {
            var photoURL: String? = nil
            if let profileImage {
                photoURL = try await StorageService.shared.uploadGuidePhoto(uid: uid, image: profileImage)
            }

            let langs = languages
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

            let profile = GuideProfile(
                id: uid,
                displayName: displayName,
                city: city,
                languages: langs.isEmpty ? ["English"] : langs,
                bio: bio,
                photoURL: photoURL,
                ratingAvg: 0,
                ratingCount: 0,
                createdAt: Date()
            )
            try await FirestoreService.shared.createGuideProfile(profile)
            Haptics.success()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}
