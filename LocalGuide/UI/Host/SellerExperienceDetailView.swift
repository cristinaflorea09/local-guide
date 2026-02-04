import SwiftUI
import FirebaseFirestore

/// Seller-facing detail view for an experience (read-only preview + edit shortcut).
struct SellerExperienceDetailView: View {
    let experience: Experience
    @State private var currentExperience: Experience
    @EnvironmentObject var appState: AppState
    @State private var experiences: [Experience] = []
    @State private var isLoading = false
    @State private var editTarget: Experience?
    @State private var experienceListener: ListenerRegistration?
    @State private var refreshToken = UUID()
    
    init(experience: Experience) {
        self.experience = experience
        _currentExperience = State(initialValue: experience)
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ExperienceCard(experience: currentExperience)

                    LuxuryCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Status").font(.headline)
                            Text(currentExperience.active ? "Active" : "Inactive")
                                .foregroundStyle(currentExperience.active ? Lx.gold : .secondary)

                            Divider().opacity(0.15)

                            Text("Pricing").font(.headline)
                            Text("€\(currentExperience.price, specifier: "%.2f") per person")
                                .foregroundStyle(.secondary)
                            Text("Max people: \(currentExperience.maxPeople)")
                                .foregroundStyle(.secondary)

                            Divider().opacity(0.15)

                            Text("Category").font(.headline)
                            Text(verbatim: String(describing: currentExperience.category ?? "Unknown"))
                                .foregroundStyle(.secondary)
                            Text(verbatim: "Difficulty: \(currentExperience.difficulty ?? "Unknown") • Effort: \(currentExperience.physicalEffort ?? "Unknown")")
                                .foregroundStyle(.secondary)
                        }
                    }

                    Button {
                        editTarget = currentExperience
                    } label: {
                        Text("Edit experience")
                    }
                    .buttonStyle(LuxuryPrimaryButtonStyle())

                    Spacer(minLength: 8)
                }
                .id(refreshToken)
                .padding(18)

            }
        }
        .navigationTitle("Details")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $editTarget) { exp in
            EditExperienceView(experience: exp) { updated in
                apply(updated)
            }
            .onDisappear {
                Task { await load() }
            }
        }
        .onAppear { startListening() }
        .onDisappear { stopListening() }
        .task { await load() }
        .onAppear { Task { await load() } }

    }
    
    private func load() async {
        guard let email = appState.session.firebaseUser?.email else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            experiences = try await FirestoreService.shared.getExperiencesForHost(hostEmail: email)
            if let updated = experiences.first(where: { $0.id == experience.id }) {
                apply(updated)
            }
        } catch {
            experiences = []
        }
    }

    private func startListening() {
        guard experienceListener == nil else { return }
        experienceListener = FirestoreService.shared.listenToExperience(experienceId: experience.id) { updated in
            guard let updated else { return }
            Task { @MainActor in
                apply(updated)
            }
        }
    }

    private func stopListening() {
        experienceListener?.remove()
        experienceListener = nil
    }

    private func apply(_ updated: Experience) {
        currentExperience = updated
        refreshToken = UUID()
    }
}
