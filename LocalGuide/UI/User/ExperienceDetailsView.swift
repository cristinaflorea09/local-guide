import SwiftUI
import FirebaseFirestore

struct ExperienceDetailsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState
    @State var experience: Experience

    @State private var host: HostProfile?
    @State private var reviews: [Review] = []
    @State private var loading = false
    @State private var chatThread: ChatThread?

    @State private var peopleCount = 1
    @State private var selectedDay = Date()
    @State private var selectedSlot: AvailabilitySlot?
    @State private var experienceListener: ListenerRegistration?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ExperienceCard(experience: experience)

                    if let host {
                        LuxuryCard {
                            HStack(spacing: 12) {
                                AvatarView(url: host.photoURL, size: 54)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(host.brandName).font(.headline)
                                    Text(host.city).font(.caption).foregroundStyle(.secondary)
                                    if host.ratingCount > 0 {
                                        StarRatingView(rating: host.ratingAvg, size: 12)
                                    }
                                    Text("HOST").font(.caption2.weight(.semibold)).foregroundStyle(Lx.gold)
                                }
                                Spacer()
                            }
        // Present details as a full page by hiding the tab bar.
        .toolbar(.hidden, for: .tabBar)
                        }
                    }

                    LuxuryCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("About this experience").font(.headline)
                            Text(experience.description)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if !reviews.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("Reviews").font(.title3.bold()).foregroundStyle(.white)
                                Spacer()
                                let avg = Double(reviews.map { $0.rating }.reduce(0, +)) / Double(reviews.count)
                                StarRatingView(rating: avg, size: 13)
                            }

                            LazyVStack(spacing: 12) {
                                ForEach(reviews.prefix(3)) { r in
                                    LuxuryCard {
                                        VStack(alignment: .leading, spacing: 6) {
                                            HStack {
                                                StarRatingView(rating: r.rating, size: 12)
                                                Spacer()
                                                Text(r.createdAt.formatted(date: .abbreviated, time: .omitted))
                                                    .font(.caption2)
                                                    .foregroundStyle(.secondary)
                                            }
                                            Text(r.comment.isEmpty ? "(No comment)" : r.comment)
                                                .foregroundStyle(.primary)
                                        }
                                    }
                                }
                            }

                            if reviews.count > 3 {
                                NavigationLink {
                                    ReviewsListView(title: "Reviews", reviews: reviews)
                                } label: {
                                    Text("See all reviews")
                                        .foregroundStyle(Lx.gold)
                                        .font(.subheadline.weight(.semibold))
                                }
                            }
                        }
                    }

                    LuxuryCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Book your experience").font(.headline)

                            Text("Choose day").font(.subheadline.weight(.semibold))
                            DatePicker("Day", selection: $selectedDay, displayedComponents: [.date])
                                .datePickerStyle(.compact)

                            Divider().opacity(0.15)

                            AvailabilityPickerView(guideEmail: experience.hostEmail, selectedDate: selectedDay, selectedSlot: $selectedSlot)

                            Divider().opacity(0.15)

                            Stepper("People: \(peopleCount)", value: $peopleCount, in: 1...max(experience.maxPeople, 1))
                                .onChange(of: peopleCount) { _ in Haptics.light() }

                            HStack {
                                Text("Total")
                                Spacer()
                                Text(String(format: "€%.2f", Double(peopleCount) * experience.price))
                            }
                            .font(.headline)
                        }
                    }

                    Button {
                        Haptics.light()
                        Task { await openChat() }
                    } label: {
                        Text("Message this host")
                    }
                    .buttonStyle(LuxuryPrimaryButtonStyle())

                    NavigationLink {
                        CheckoutExperienceView(experience: experience, slot: selectedSlot, peopleCount: peopleCount, total: Double(peopleCount) * experience.price)
                    } label: {
                        Text("Continue to payment")
                    }
                    .buttonStyle(LuxurySecondaryButtonStyle())
                    .disabled(selectedSlot == nil)
                }
                .padding(18)
            }

            if loading {
                ProgressView().tint(Lx.gold)
            }
        }
        .navigationTitle("Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.headline)
                        .foregroundStyle(Lx.gold)
                }
                .accessibilityLabel("Close")
            }
        }
        .task {
            await loadExtras()
            await reloadExperience()
        }
        .onAppear { startListening() }
        .onDisappear { stopListening() }
        .navigationDestination(item: $chatThread) { thread in
            ChatView(thread: thread)
                .environmentObject(appState)
        }
    }

    private func loadExtras() async {
        if loading { return }
        loading = true
        defer { loading = false }
        host = try? await FirestoreService.shared.getHostProfile(hostEmail:experience.hostEmail)
        reviews = (try? await FirestoreService.shared.getReviewsForListing(listingType: "experience", listingId: experience.id, limit: 20)) ?? []
    }

    private func openChat() async {
        guard let uid = appState.session.firebaseUser?.uid else { return }
        do {
            let thread = try await FirestoreService.shared.getOrCreateThread(userId: uid, email: experience.hostEmail, tourId: experience.id)
            await MainActor.run { chatThread = thread }
        } catch {
            // no-op
        }
    }

    private func reloadExperience() async {
        if let latest = try? await FirestoreService.shared.getExperience(experienceId: experience.id) {
            await MainActor.run { self.experience = latest }
        }
    }

    private func startListening() {
        guard experienceListener == nil else { return }
        experienceListener = FirestoreService.shared.listenToExperience(experienceId: experience.id) { updated in
            guard let updated else { return }
            Task { @MainActor in
                self.experience = updated
            }
        }
    }

    private func stopListening() {
        experienceListener?.remove()
        experienceListener = nil
    }
}
