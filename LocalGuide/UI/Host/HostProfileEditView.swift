import SwiftUI

struct HostProfileEditView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var brandName = ""
    @State private var country = ""
    @State private var city = ""
    @State private var categories = ""
    @State private var bio = ""
    @State private var acceptsCustomRequestsLocal: Bool = false
    @State private var profileImage: UIImage?
    @State private var remotePhotoURL: String?

    @State private var isLoading = false
    @State private var message: String?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Host Profile")
                        .font(.largeTitle.bold())
                        .foregroundStyle(.white)
                        .padding(.top, 8)

                    LuxuryCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Profile photo").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                            ImagePicker(image: $profileImage)

                            if let img = profileImage {
                                HStack { Spacer()
                                    Image(uiImage: img).resizable().scaledToFill()
                                        .frame(width: 92, height: 92)
                                        .clipShape(Circle())
                                        .overlay(Circle().stroke(Lx.gold.opacity(0.22), lineWidth: 1))
                                    Spacer()
                                }
                            } else if let remotePhotoURL, let url = URL(string: remotePhotoURL) {
                                HStack { Spacer()
                                    AsyncImage(url: url) { phase in
                                        switch phase {
                                        case .success(let img): img.resizable().scaledToFill()
                                        default: Circle().fill(.white.opacity(0.08))
                                        }
                                    }
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
                            Divider().opacity(0.15)
                            Toggle("Accept custom requests", isOn: $acceptsCustomRequestsLocal)
                                .tint(Lx.gold)
                        }
                    }

                    if let message { Text(message).foregroundStyle(.white.opacity(0.75)) }

                    Button { Task { await save() } } label: {
                        if isLoading { ProgressView().tint(.black) } else { Text("Save changes") }
                    }
                    .buttonStyle(LuxuryPrimaryButtonStyle())
                    .disabled(isLoading)

                    Spacer(minLength: 12)
                }
                .padding(18)
            }
        }
        .navigationTitle("Host")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func load() async {
        guard let uid = appState.session.firebaseUser?.uid else { return }
        guard let hostEmail =  appState.session.firebaseUser?.email else { return }
        do {
            let p = try await FirestoreService.shared.getHostProfile(hostEmail: hostEmail)
            brandName = p.brandName
            country = p.country
            city = p.city
            categories = p.categories.joined(separator: ", ")
            bio = p.bio
            remotePhotoURL = p.photoURL
            acceptsCustomRequestsLocal = p.acceptsCustomRequests ?? false
        } catch {
            message = error.localizedDescription
        }
    }

    private func save() async {
        guard let uid = appState.session.firebaseUser?.uid else { return }
        guard let hostEmail = appState.session.firebaseUser?.email else { return }
        isLoading = true
        message = nil

        do {
            var p = try await FirestoreService.shared.getHostProfile(hostEmail: hostEmail)
            p.brandName = brandName.trimmingCharacters(in: .whitespacesAndNewlines)
            p.country = country
            p.city = city
            p.categories = categories.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
            p.bio = bio
            p.acceptsCustomRequests = acceptsCustomRequestsLocal

            if let profileImage {
                p.photoURL = try await StorageService.shared.uploadUserPhoto(uid: uid, image: profileImage)
            }

            try await FirestoreService.shared.updateHostProfile(p)
            message = "Saved ✅"
            Haptics.success()
            await appState.session.refreshCurrentUserIfAvailable()
            await MainActor.run { dismiss() }
        } catch {
            message = error.localizedDescription
        }

        isLoading = false
    }
}

