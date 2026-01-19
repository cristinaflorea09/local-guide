import SwiftUI

struct TourDetailsView: View {
    @EnvironmentObject var appState: AppState
    let tour: Tour

    @State private var peopleCount = 1
    @State private var selectedDay = Date()
    @State private var selectedSlot: AvailabilitySlot?

    @State private var guide: GuideProfile?
    @State private var reviews: [Review] = []
    @State private var loadingExtras = false

    @State private var showBreakdown = false

    @State private var chatThread: ChatThread?
    @State private var goToCheckout = false

    var baseTotal: Double { Double(peopleCount) * tour.price }
    var finalTotal: Double { appState.subscription.isPremium ? baseTotal * 0.9 : baseTotal }

    var avgTourRating: Double {
        if reviews.isEmpty { return guide?.ratingAvg ?? 0 }
        return Double(reviews.map { $0.rating }.reduce(0, +)) / Double(reviews.count)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    TourCard(tour: tour, subtitle: tour.description)

                    if let guide {
                        LuxuryCard {
                            HStack(spacing: 12) {
                                avatar(url: guide.photoURL)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(guide.displayName).font(.headline)
                                    Text(guide.city).font(.caption).foregroundStyle(.secondary)
                                    StarRatingView(rating: max(avgTourRating, 0.0))
                                }
                                Spacer()
                                LuxuryPill(text: "GUIDE")
                            }
                        }
                    }

                    LuxuryCard {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("Book your experience").font(.headline)
                                Spacer()
                                Button {
                                    Haptics.light()
                                    showBreakdown = true
                                } label: {
                                    Text("Price breakdown")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(Lx.gold)
                                }
                            }

                            Text("Choose day").font(.subheadline.weight(.semibold))
                            DatePicker("Tour day", selection: $selectedDay, displayedComponents: [.date])
                                .datePickerStyle(.compact)

                            Divider().opacity(0.15)

                            AvailabilityPickerView(guideId: tour.guideId, selectedDate: selectedDay, selectedSlot: $selectedSlot)

                            Divider().opacity(0.15)

                            Stepper("People: \(peopleCount)", value: $peopleCount, in: 1...tour.maxPeople)
                                .onChange(of: peopleCount) { _ in Haptics.light() }

                            VStack(alignment: .leading, spacing: 6) {
                                HStack { Text("Total"); Spacer(); Text("€\(baseTotal, specifier: "%.2f")") }
                                    .foregroundStyle(.secondary)
                                if appState.subscription.isPremium {
                                    HStack { Text("Premium discount"); Spacer(); Text("-10%") }
                                        .foregroundStyle(.secondary)
                                }
                                HStack { Text("Pay"); Spacer(); Text("€\(finalTotal, specifier: "%.2f")") }
                                    .font(.headline)
                            }
                        }
                    }

                    if !reviews.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("Reviews").font(.title3.bold()).foregroundStyle(.white)
                                Spacer()
                                StarRatingView(rating: avgTourRating, size: 13)
                            }

                            LazyVStack(spacing: 12) {
                                ForEach(reviews.prefix(3)) { r in
                                    LuxuryCard {
                                        VStack(alignment: .leading, spacing: 6) {
                                            HStack {
                                                StarRatingView(rating: Double(r.rating), size: 12)
                                                Spacer()
                                                Text(r.createdAt.formatted(date: .abbreviated, time: .omitted))
                                                    .font(.caption2)
                                                    .foregroundStyle(.secondary)
                                            }
                                            Text(r.comment)
                                                .foregroundStyle(.primary)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Button {
                        Haptics.light()
                        Task { await openChat() }
                    } label: {
                        Text("Message this guide")
                    }
                    .buttonStyle(LuxurySecondaryButtonStyle())

                    Button {
                        Haptics.medium()
                        goToCheckout = true
                    } label: {
                        Text("Continue to payment")
                    }
                    .buttonStyle(LuxuryPrimaryButtonStyle())
                    .disabled(selectedSlot == nil)

                    Spacer(minLength: 8)
                }
                .padding(18)
            }

            if loadingExtras {
                VStack { ProgressView().tint(Lx.gold) }
                    .padding()
                    .background(.thinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
        .navigationTitle("Details")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadExtras() }
        .sheet(isPresented: $showBreakdown) {
            PriceBreakdownSheet(pricePerPerson: tour.price, peopleCount: peopleCount, isPremium: appState.subscription.isPremium)
        }
        .navigationDestination(isPresented: $goToCheckout) {
            CheckoutView(tour: tour, slot: selectedSlot, peopleCount: peopleCount, total: finalTotal)
        }
        .fullScreenCover(item: $chatThread) { thread in
            NavigationStack {
                ChatView(thread: thread)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Close") { chatThread = nil }
                                .foregroundStyle(Lx.gold)
                        }
                    }
            }
        }
        // Present details as a full page by hiding the tab bar.
        .toolbar(.hidden, for: .tabBar)
    }

    private func avatar(url: String?) -> some View {
        ZStack {
            Circle().fill(Color.white.opacity(0.10)).frame(width: 54, height: 54)
                .overlay(Circle().stroke(Lx.gold.opacity(0.22), lineWidth: 1))
            if let url, let u = URL(string: url) {
                AsyncImage(url: u) { phase in
                    switch phase {
                    case .success(let img):
                        img
                            .resizable()
                            .scaledToFill()
                    case .empty:
                        ProgressView()
                    case .failure(_):
                        Image(systemName: "person.fill")
                            .foregroundStyle(Lx.gold)
                    @unknown default:
                        Image(systemName: "person.fill")
                            .foregroundStyle(Lx.gold)
                    }
                }
                .frame(width: 54, height: 54)
                .clipShape(Circle())
            } else {
                Image(systemName: "person.fill").foregroundStyle(Lx.gold)
            }
        }
    }

    private func loadExtras() async {
        if loadingExtras { return }
        loadingExtras = true
        defer { loadingExtras = false }
        do {
            guide = try await FirestoreService.shared.getGuideProfile(guideId: tour.guideId)
        } catch { }
        do {
            reviews = try await FirestoreService.shared.getReviewsForTour(tourId: tour.id, limit: 20)
        } catch {
            reviews = []
        }
    }

    private func openChat() async {
        guard let uid = appState.session.firebaseUser?.uid else { return }
        do {
            let thread = try await FirestoreService.shared.getOrCreateThread(userId: uid, guideId: tour.guideId, tourId: tour.id)
            await MainActor.run { chatThread = thread }
        } catch { }
    }
}
