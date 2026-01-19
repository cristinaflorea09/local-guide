import SwiftUI

/// Seller-facing detail view for an experience (read-only preview + edit shortcut).
struct SellerExperienceDetailView: View {
    let experience: Experience

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ExperienceCard(experience: experience)

                    LuxuryCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Status").font(.headline)
                            Text(experience.active ? "Active" : "Inactive")
                                .foregroundStyle(experience.active ? Lx.gold : .secondary)

                            Divider().opacity(0.15)

                            Text("Pricing").font(.headline)
                            Text("€\(experience.price, specifier: "%.2f") per person")
                                .foregroundStyle(.secondary)
                            Text("Max people: \(experience.maxPeople)")
                                .foregroundStyle(.secondary)

                            Divider().opacity(0.15)

                            Text("Category").font(.headline)
                            Text(verbatim: String(describing: experience.category ?? "Unknown"))
                                .foregroundStyle(.secondary)
                            Text(verbatim: "Difficulty: \(experience.difficulty ?? "Unknown") • Effort: \(experience.physicalEffort ?? "Unknown")")
                                .foregroundStyle(.secondary)
                        }
                    }

                    NavigationLink { EditExperienceView(experience: experience) } label: {
                        Text("Edit experience")
                    }
                    .buttonStyle(LuxuryPrimaryButtonStyle())

                    Spacer(minLength: 8)
                }
                .padding(18)
            }
        }
        .navigationTitle("Details")
        .navigationBarTitleDisplayMode(.inline)
    }
}
