import SwiftUI

struct HostProfileSetupView: View {
    @EnvironmentObject var appState: AppState

    @State private var brandName = ""
    @State private var country = ""
    @State private var city = ""
    @State private var categories = "Cooking, Wine, Crafts"
    @State private var bio = ""
    @State private var profileImage: UIImage?

    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Host profile")
                        .font(.largeTitle.bold())
                        .foregroundStyle(.white)
                        .padding(.top, 8)

                    Text("Hosts sell cultural experiences (classes, tastings, workshops). This is different from licensed tour guiding.")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.65))

                    LuxuryCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Profile photo")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)

                            ImagePicker(image: $profileImage)

                            if let img = profileImage {
                                HStack { Spacer()
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

                            LuxuryTextField(title: "Brand / Host name", text: $brandName)

                            Text("Location").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                            CountryPicker(country: $country)
                            CityPicker(city: $city, country: country)

                            LuxuryTextField(title: "Categories (comma separated)", text: $categories)
                            LuxuryTextField(title: "Bio", text: $bio)
                        }
                    }

                    if let errorMessage { Text(errorMessage).foregroundStyle(.red) }

                    Button { Task { await save() } } label: {
                        if isLoading { ProgressView().tint(.black) } else { Text("Save") }
                    }
                    .buttonStyle(LuxuryPrimaryButtonStyle())
                    .disabled(isLoading || brandName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || country.isEmpty || city.isEmpty)

                    Spacer(minLength: 12)
                }
                .padding(18)
            }
        }
        .navigationTitle("Host")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func save() async {
        guard let uid = appState.session.firebaseUser?.uid else { return }
        isLoading = true
        errorMessage = nil

        do {
            var photoURL: String? = nil
            if let profileImage {
                // reuse user photo path for hosts
                photoURL = try await StorageService.shared.uploadUserPhoto(uid: uid, image: profileImage)
            }

            let cats = categories
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

            let profile = HostProfile(
                id: uid,
                brandName: brandName.trimmingCharacters(in: .whitespacesAndNewlines),
                country: country,
                city: city,
                categories: cats,
                bio: bio,
                photoURL: photoURL,
                createdAt: Date()
            )

            try await FirestoreService.shared.createHostProfile(profile)
            await appState.session.refreshCurrentUserIfAvailable()
            Haptics.success()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}
