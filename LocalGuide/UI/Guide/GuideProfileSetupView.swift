import SwiftUI
import UniformTypeIdentifiers

struct GuideProfileSetupView: View {
    @EnvironmentObject var appState: AppState

    @State private var displayName = ""
    @State private var country = ""
    @State private var city = ""
    @State private var languages = "English"
    @State private var bio = ""
    @State private var profileImage: UIImage?

    // Attestation upload (for RO/EU compliance where required)
    @State private var showAttestationPicker = false
    @State private var attestationData: Data?
    @State private var attestationFileName: String?
    @State private var attestationContentType: String = "application/pdf"

    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Guide profile")
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
                                Text("Guide attestation (optional but recommended)")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)

                                Text("If your jurisdiction requires a guide authorization/attestation, upload it here. This helps marketplace compliance (RO/EU).")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                Button {
                                    showAttestationPicker = true
                                } label: {
                                    Text(attestationFileName == nil ? "Upload attestation" : "Replace attestation (\(attestationFileName!))")
                                }
                                .buttonStyle(LuxurySecondaryButtonStyle())
                            }

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
                        if isLoading { ProgressView().tint(.black) } else { Text("Save") }
                    }
                    .buttonStyle(LuxuryPrimaryButtonStyle())
                    .disabled(isLoading || displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || country.isEmpty || city.isEmpty)

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
                    errorMessage = error.localizedDescription
                }
            case .failure(let error):
                errorMessage = error.localizedDescription
            }
        }
        .navigationTitle("Guide")
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

            var attestationURL: String? = nil
            if let attestationData, let attestationFileName {
                attestationURL = try await StorageService.shared.uploadGuideAttestation(
                    uid: uid,
                    data: attestationData,
                    fileName: attestationFileName,
                    contentType: attestationContentType
                )
            }

            let langs = languages
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

            let profile = GuideProfile(
                id: uid,
                displayName: displayName.trimmingCharacters(in: .whitespacesAndNewlines),
                country: country,
                city: city,
                languages: langs.isEmpty ? ["English"] : langs,
                bio: bio,
                photoURL: photoURL,
                attestationURL: attestationURL,
                ratingAvg: 0,
                ratingCount: 0,
                createdAt: Date()
            )

            try await FirestoreService.shared.createGuideProfile(profile)
            await appState.session.refreshCurrentUserIfAvailable()
            Haptics.success()
            
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}
