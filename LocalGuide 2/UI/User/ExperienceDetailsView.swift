import SwiftUI

struct ExperienceDetailsView: View {
    @EnvironmentObject var appState: AppState
    let experience: Experience

    @State private var host: HostProfile?
    @State private var reviews: [Review] = []
    @State private var loading = false

    @State private var peopleCount = 1
    @State private var selectedDay = Date()
    @State private var selectedSlot: AvailabilitySlot?

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

                            AvailabilityPickerView(guideId: experience.hostId, selectedDate: selectedDay, selectedSlot: $selectedSlot)

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
        .task { await loadExtras() }
    }

    private func loadExtras() async {
        if loading { return }
        loading = true
        defer { loading = false }
        host = try? await FirestoreService.shared.getHostProfile(hostId: experience.hostId)
        reviews = (try? await FirestoreService.shared.getReviewsForListing(listingType: "experience", listingId: experience.id, limit: 20)) ?? []
    }

    private func openChat() async {
        guard let uid = appState.session.firebaseUser?.uid else { return }
        do { _ = try await FirestoreService.shared.getOrCreateThread(userId: uid, guideId: experience.hostId, tourId: experience.id) } catch { }
    }
}
