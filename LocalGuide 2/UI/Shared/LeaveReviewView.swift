import SwiftUI

struct LeaveReviewView: View {
    @EnvironmentObject var appState: AppState
    let booking: Booking
    let listingTitle: String
    let providerName: String

    @Environment(\.dismiss) private var dismiss
    @State private var rating: Int = 5
    @State private var comment: String = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                VStack(alignment: .leading, spacing: 16) {
                    LuxuryCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Leave a review")
                                .font(.title2.bold())
                                .foregroundStyle(.white)
                            Text("\(listingTitle) • \(providerName)")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.75))

                            StarRatingView(rating: rating) { newValue in
                                rating = newValue
                            }
                            .padding(.top, 4)
                        }
                    }

                    LuxuryCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Comment")
                                .foregroundStyle(.white.opacity(0.85))
                                .font(.subheadline.weight(.semibold))
                            TextField("Share details...", text: $comment, axis: .vertical)
                                .textFieldStyle(LuxuryTextFieldStyle())
                                .lineLimit(4, reservesSpace: true)
                        }
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .font(.footnote)
                    }

                    Button {
                        Task { await submit() }
                    } label: {
                        HStack {
                            Spacer()
                            if isSubmitting { ProgressView().tint(.black) }
                            Text(isSubmitting ? "Submitting..." : "Submit review")
                                .font(.headline)
                            Spacer()
                        }
                    }
                    .buttonStyle(LuxuryPrimaryButtonStyle())
                    .disabled(isSubmitting)

                    Spacer()
                }
                .padding(18)
            }
            .navigationTitle("Review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(Lx.gold)
                }
            }
        }
    }

    private func submit() async {
        guard let uid = appState.session.firebaseUser?.uid else { return }
        isSubmitting = true
        errorMessage = nil
        do {
            try await ReviewService.shared.submitReview(
                booking: booking,
                userId: uid,
                rating: rating,
                comment: comment.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        isSubmitting = false
    }
}
