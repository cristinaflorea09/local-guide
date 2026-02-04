import SwiftUI

struct CommunityGuidelinesView: View {
    @Environment(\.openURL) private var openURL

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Community Guidelines")
                        .font(.largeTitle.bold())
                        .foregroundStyle(.white)

                    guidelineCard(title: "Be respectful", body: "Treat everyone with kindness. Harassment, hate speech, or discrimination are not allowed.")
                    guidelineCard(title: "Keep it relevant", body: "Post content related to travel, tours, experiences, and local tips. Spam or misleading content is removed.")
                    guidelineCard(title: "No illegal or harmful content", body: "Do not post illegal activities, threats, violent content, or anything that endangers others.")
                    guidelineCard(title: "Protect privacy", body: "Do not share personal data (addresses, phone numbers, IDs) without consent.")
                    guidelineCard(title: "Reviews must be honest", body: "Reviews and reports should be truthful and based on real experiences.")

                    LuxuryCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Reporting & enforcement")
                                .font(.headline)
                                .foregroundStyle(.white)
                            Text("You can report posts or comments. We may remove content or restrict accounts that violate these guidelines.")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.75))
                        }
                    }

                    LuxuryCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Contact support")
                                .font(.headline)
                                .foregroundStyle(.white)
                            Text("If you need help or want to report an urgent issue, contact us.")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.75))
                            Button("Email support") {
                                contactSupport()
                            }
                            .buttonStyle(LuxurySecondaryButtonStyle())
                        }
                    }

                    Spacer(minLength: 12)
                }
                .padding(18)
            }
        }
        .navigationTitle("Guidelines")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func guidelineCard(title: String, body: String) -> some View {
        LuxuryCard {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)
                Text(body)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.75))
            }
        }
    }

    private func contactSupport() {
        let email = AppConfig.supportEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !email.isEmpty, let url = URL(string: "mailto:\(email)") else { return }
        openURL(url)
    }
}
