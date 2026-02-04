import SwiftUI

/// Traveler-facing directory that lists Guides and Hosts who opted in to receive custom requests.
/// Allows searching by city/country/name and opens the request form prefilled with provider email.
struct CustomRequestDirectoryView: View {
    @EnvironmentObject var appState: AppState

    @State private var query: String = ""
    @State private var city: String = ""
    @State private var country: String = ""

    @State private var guides: [GuideProfile] = []
    @State private var hosts: [HostProfile] = []
    @State private var isLoading = false
    @State private var message: String?

    @State private var selectedProviderEmail: String?
    @State private var showRequestForm = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Custom Requests")
                        .font(.largeTitle.bold())
                        .foregroundStyle(.white)
                        .padding(.top, 8)

                    LuxuryCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Find a provider")
                                .font(.headline)
                            LuxuryTextField(title: "Search name or category", text: $query)
                            Text("Filter by location")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            CountryPicker(country: $country)
                            CityPicker(city: $city, country: country)

                            Button {
                                Haptics.medium()
                                Task { await load() }
                            } label: {
                                Text("Search")
                            }
                            .buttonStyle(LuxuryPrimaryButtonStyle())
                        }
                    }

                    if let message {
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.75))
                    }

                    if isLoading {
                        LuxuryCard { ProgressView().tint(Lx.gold) }
                    }

                    if !guides.isEmpty {
                        Text("Guides")
                            .font(.headline)
                            .foregroundStyle(.white)
                        ForEach(guides, id: \.id) { g in
                            providerRow(name: g.displayName, email: g.id, location: "\(g.city), \(g.country)", rating: g.ratingAvg, count: g.ratingCount, photoURL: g.photoURL)
                        }
                    }

                    if !hosts.isEmpty {
                        Text("Hosts")
                            .font(.headline)
                            .foregroundStyle(.white)
                        ForEach(hosts, id: \.id) { h in
                            providerRow(name: h.brandName, email: h.id, location: "\(h.city), \(h.country)", rating: h.ratingAvg, count: h.ratingCount, photoURL: h.photoURL)
                        }
                    }

                    if !isLoading && guides.isEmpty && hosts.isEmpty {
                        LuxuryCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("No matching providers")
                                    .font(.headline)
                                Text("Try a broader search or a different location.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    Spacer(minLength: 12)
                }
                .padding(18)
            }
        }
        .navigationTitle("Custom Requests")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .fullScreenCover(isPresented: $showRequestForm) {
            NavigationStack {
                CustomRequestFormView(prefilledProviderEmail: selectedProviderEmail)
                    .environmentObject(appState)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button { showRequestForm = false } label: { Image(systemName: "chevron.left") }
                        }
                    }
            }
        }
    }

    @ViewBuilder
    private func providerRow(name: String, email: String, location: String, rating: Double, count: Int, photoURL: String?) -> some View {
        LuxuryCard {
            HStack(spacing: 12) {
                AvatarView(url: photoURL, size: 52)
                VStack(alignment: .leading, spacing: 4) {
                    Text(name)
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text(location)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                    HStack(spacing: 6) {
                        Image(systemName: "star.fill").foregroundStyle(Lx.gold).font(.caption2)
                        Text(String(format: "%.1f", rating)).font(.caption)
                        Text("(\(count))").font(.caption2).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Button {
                    selectedProviderEmail = email
                    showRequestForm = true
                } label: {
                    Text("Request custom")
                }
                .buttonStyle(LuxurySecondaryButtonStyle())
            }
        }
    }

    private func load() async {
        isLoading = true
        message = nil
        defer { isLoading = false }

        do {
            // Load providers who opted in. We don't have server-side queries by flag,
            // so we fetch lists and filter client-side for now.
            async let gAll = FirestoreService.shared.listGuides(limit: 200)
            async let hAll = FirestoreService.shared.listHosts(limit: 200)
            let (g, h) = try await (gAll, hAll)

            let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let cityQ = city.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let countryQ = country.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

            guides = g.filter { gp in
                (gp.acceptsCustomRequests ?? false)
                && (q.isEmpty || gp.displayName.lowercased().contains(q))
                && (cityQ.isEmpty || gp.city.lowercased().contains(cityQ))
                && (countryQ.isEmpty || gp.country.lowercased().contains(countryQ))
            }

            hosts = h.filter { hp in
                (hp.acceptsCustomRequests ?? false)
                && (q.isEmpty || hp.brandName.lowercased().contains(q) || hp.categories.joined(separator: ", ").lowercased().contains(q))
                && (cityQ.isEmpty || hp.city.lowercased().contains(cityQ))
                && (countryQ.isEmpty || hp.country.lowercased().contains(countryQ))
            }
        } catch {
            message = error.localizedDescription
            guides = []
            hosts = []
        }
    }
}
