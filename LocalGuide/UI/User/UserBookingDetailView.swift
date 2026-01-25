import SwiftUI

struct UserBookingDetailView: View {
    @EnvironmentObject var appState: AppState
    let booking: Booking

    @State private var listingTitle: String = ""
    @State private var providerName: String = ""
    @State private var existingReview: Review? = nil
    @State private var showLeaveReview = false
    @State private var loading = false

    var canReview: Bool {
        booking.isPastEnd && (booking.status == .confirmed) && existingReview == nil
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    LuxuryCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(listingTitle.isEmpty ? "Booking" : listingTitle)
                                .font(.title3.bold())
                                .foregroundStyle(.white)
                            Text(providerName)
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.75))
                            Text("Status: \(booking.status.rawValue)")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.7))
                        }
                    }

                    LuxuryCard {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack { Text("Start"); Spacer(); Text(booking.startDate.formatted(date: .abbreviated, time: .shortened)) }
                            HStack { Text("End"); Spacer(); Text(booking.endDate.formatted(date: .abbreviated, time: .shortened)) }
                            HStack { Text("People"); Spacer(); Text("\(booking.peopleCount)") }
                            HStack { Text("Total"); Spacer(); Text("\(booking.currency.uppercased()) \(booking.totalPrice, specifier: "%.2f")") }
                        }
                        .foregroundStyle(.white.opacity(0.85))
                        .font(.subheadline)
                    }

                    if let existingReview {
                        LuxuryCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Your review")
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                StarRatingView(rating: existingReview.rating)
                                Text(existingReview.comment.isEmpty ? "(No comment)" : existingReview.comment)
                                    .foregroundStyle(.white.opacity(0.9))
                                    .font(.subheadline)
                            }
                        }
                    }

                    if canReview {
                        Button {
                            showLeaveReview = true
                        } label: {
                            Text("Leave a review")
                        }
                        .buttonStyle(LuxuryPrimaryButtonStyle())
                    } else if !booking.isPastEnd {
                        Text("You can leave a review after the session ends.")
                            .foregroundStyle(.white.opacity(0.65))
                            .font(.footnote)
                    }
                }
                .padding(18)
            }

            if loading {
                ProgressView().tint(Lx.gold)
            }
        }
        .navigationTitle("Booking")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .sheet(isPresented: $showLeaveReview) {
            LeaveReviewView(booking: booking, listingTitle: listingTitle.isEmpty ? "Listing" : listingTitle, providerName: providerName.isEmpty ? "Provider" : providerName)
                .environmentObject(appState)
        }
        .onChange(of: showLeaveReview) { oldValue, newValue in
            if !newValue {
                Task { await loadReviewOnly() }
            }
        }
    }

    private func load() async {
        if loading { return }
        loading = true
        defer { loading = false }

        await loadListingAndProvider()
        await loadReviewOnly()
    }

    private func loadReviewOnly() async {
        existingReview = (try? await FirestoreService.shared.getReviewForBooking(bookingId: booking.id)) ?? nil
    }

    private func loadListingAndProvider() async {
        let lt = booking.effectiveListingType
        let lid = booking.effectiveListingId
        let pid = booking.effectiveProviderId
        if lt == "experience" {
            if let exp = try? await FirestoreService.shared.getExperience(experienceId: lid) {
                listingTitle = exp.title
            }
            if let host = try? await FirestoreService.shared.getHostProfile(hostEmail: pid) {
                providerName = host.brandName
            }
        } else {
            if let tour = try? await FirestoreService.shared.getTour(tourId: lid) {
                listingTitle = tour.title
            }
            if let guide = try? await FirestoreService.shared.getGuideProfile(guideEmail: pid) {
                providerName = guide.displayName
            }
        }
    }
}

