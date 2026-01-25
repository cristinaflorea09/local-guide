import SwiftUI
import UniformTypeIdentifiers

struct GuideProfileEditView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var displayName = ""
    @State private var country = ""
    @State private var city = ""
    @State private var languages = ""
    @State private var bio = ""

    @State private var profileImage: UIImage?
    @State private var remotePhotoURL: String?
    @State private var remoteAttestationURL: String?

    @State private var showAttestationPicker = false
    @State private var attestationData: Data?
    @State private var attestationFileName: String?
    @State private var attestationContentType: String = "application/pdf"

    @State private var isLoading = false
    @State private var message: String?

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
                                HStack { Spacer()
                                    Image(uiImage: img)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 92, height: 92)
                                        .clipShape(Circle())
                                        .overlay(Circle().stroke(Lx.gold.opacity(0.22), lineWidth: 1))
                                    Spacer()
                                }
                            } else if let remotePhotoURL, let url = URL(string: remotePhotoURL) {
                                HStack { Spacer()
                                    AsyncImage(url: url) { phase in
                                        switch phase {
                                        case .success(let img):
                                            img.resizable().scaledToFill()
                                        default:
                                            Circle().fill(.white.opacity(0.08))
                                        }
                                    }
                                    .frame(width: 92, height: 92)
                                    .clipShape(Circle())
                                    .overlay(Circle().stroke(Lx.gold.opacity(0.22), lineWidth: 1))
                                    Spacer()
                                }
                            }

                            Divider().opacity(0.15)

                            LuxuryTextField(title: "Display name", text: $displayName)
                            Text("Location").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                            CountryPicker(country: $country)
                            CityPicker(city: $city, country: country)

                            LuxuryTextField(title: "Languages (comma separated)", text: $languages)
                            LuxuryTextField(title: "Bio", text: $bio)

                            Divider().opacity(0.15)

                            VStack(alignment: .leading, spacing: 8) {
                                Text("Guide attestation")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)

                                if remoteAttestationURL != nil {
                                    Text("Attestation uploaded ✅")
                                        .font(.caption)
                                        .foregroundStyle(.white.opacity(0.7))
                                }

                                Button {
                                    showAttestationPicker = true
                                } label: {
                                    Text(attestationFileName == nil ? "Upload / replace attestation" : "Selected: \(attestationFileName!)")
                                }
                                .buttonStyle(LuxurySecondaryButtonStyle())
                            }
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
        .fileImporter(isPresented: $showAttestationPicker,
                      allowedContentTypes: [UTType.pdf, UTType.image],
                      allowsMultipleSelection: false) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                do {
                    let data = try Data(contentsOf: url)
                    attestationData = data
                    attestationFileName = url.lastPathComponent
                    if url.pathExtension.lowercased() == "pdf" {
                        attestationContentType = "application/pdf"
                    } else if url.pathExtension.lowercased() == "png" {
                        attestationContentType = "image/png"
                    } else {
                        attestationContentType = "image/jpeg"
                    }
                } catch {
                    message = error.localizedDescription
                }
            case .failure(let error):
                message = error.localizedDescription
            }
        }
        .navigationTitle("Guide")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func load() async {
        guard let uid = appState.session.firebaseUser?.uid else { return }
        guard let guideEmail = appState.session.currentUser?.email else { return }
        do {
            let p = try await FirestoreService.shared.getGuideProfile(guideEmail: guideEmail)
            displayName = p.displayName
            country = p.country
            city = p.city
            languages = p.languages.joined(separator: ", ")
            bio = p.bio
            remotePhotoURL = p.photoURL
            remoteAttestationURL = p.attestationURL
        } catch {
            message = error.localizedDescription
        }
    }

    private func save() async {
        guard let uid = appState.session.firebaseUser?.uid else { return }
        guard let guideEmail = appState.session.currentUser?.email else { return }
        isLoading = true
        message = nil

        do {
            var p = try await FirestoreService.shared.getGuideProfile(guideEmail: guideEmail)

            p.displayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
            p.country = country
            p.city = city
            p.languages = languages.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
            p.bio = bio

            if let profileImage {
                p.photoURL = try await StorageService.shared.uploadGuidePhoto(uid: uid, image: profileImage)
            }

            if let attestationData, let attestationFileName {
                p.attestationURL = try await StorageService.shared.uploadGuideAttestation(
                    uid: uid,
                    data: attestationData,
                    fileName: attestationFileName,
                    contentType: attestationContentType
                )
            }

            try await FirestoreService.shared.updateGuideProfile(p)
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
