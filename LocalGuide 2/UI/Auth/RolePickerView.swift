import SwiftUI

struct RolePickerView: View {
    @EnvironmentObject var router: AuthRouter

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Choose your account")
                        .font(.title.bold())
                        .foregroundStyle(.white)
                        .padding(.top, 8)

                    Text("Book premium tours, or publish luxury cultural experiences.")
                        .foregroundStyle(.white.opacity(0.7))

                    LuxuryCard {
                        VStack(spacing: 12) {
                            Button {
                                router.path.append(.register(.traveler))
                            } label: {
                                row(title: "Traveler", subtitle: "Book luxury tours", icon: "suitcase.rolling.fill")
                            }
                            Divider().opacity(0.15)

                            Button {
                                router.path.append(.register(.host))
                            } label: {
                                row(title: "Experience Host", subtitle: "Sell cultural experiences", icon: "sparkles")
                            }
                            Divider().opacity(0.15)

                            Button {
                                router.path.append(.register(.guide))
                            } label: {
                                row(title: "Guide", subtitle: "Host premium tours", icon: "map.fill")
                            }

                            Divider().opacity(0.15)

                            // Temporary: allow creating an Admin account for bootstrapping.
                            // Remove this button after you finish setting up admin users.
                            Button {
                                router.path.append(.register(.admin))
                            } label: {
                                row(title: "Admin (temporary)", subtitle: "Backoffice / moderation", icon: "shield.lefthalf.filled")
                            }
                        }
                    }
                }
                .padding(18)
            }
        }
        .navigationTitle("Register")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func row(title: String, subtitle: String, icon: String) -> some View {
        HStack {
            Image(systemName: icon).foregroundStyle(Lx.gold).frame(width: 22)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "arrow.right")
        }
        .foregroundStyle(.primary)
    }
}
