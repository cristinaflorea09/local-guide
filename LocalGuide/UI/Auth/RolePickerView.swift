import SwiftUI

struct RolePickerView: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Choose your account")
                        .font(.title.bold())
                        .foregroundStyle(.white)
                        .padding(.top, 8)

                    Text("Book premium tours or apply to host luxury experiences.")
                        .foregroundStyle(.white.opacity(0.7))

                    LuxuryCard {
                        VStack(spacing: 12) {
                            NavigationLink { RegisterView(role: .user) } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Traveler").font(.headline)
                                        Text("Book luxury tours").font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "arrow.right")
                                }
                            }
                            .buttonStyle(.plain)

                            Divider().opacity(0.15)

                            NavigationLink { RegisterView(role: .guide) } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Guide").font(.headline)
                                        Text("Host premium experiences").font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "arrow.right")
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(18)
            }
        }
        .navigationTitle("Register")
        .navigationBarTitleDisplayMode(.inline)
    }
}
