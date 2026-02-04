import SwiftUI

struct ProviderCustomRequestsView: View {
    @EnvironmentObject var appState: AppState

    @State private var requests: [CustomRequest] = []
    @State private var isLoading = false
    @State private var message: String?

    // Status filter
    private enum Filter: String, CaseIterable, Identifiable {
        case all, pending, accepted, declined, completed
        var id: String { rawValue }
        var title: String {
            switch self {
            case .all: return "All"
            case .pending: return "Pending"
            case .accepted: return "Accepted"
            case .declined: return "Declined"
            case .completed: return "Completed"
            }
        }
    }
    @State private var filter: Filter = .all

    private var filteredRequests: [CustomRequest] {
        let sorted = requests.sorted { ($0.createdAt) > ($1.createdAt) }
        switch filter {
        case .all: return sorted
        case .pending: return sorted.filter { $0.status == .pending }
        case .accepted: return sorted.filter { $0.status == .accepted }
        case .declined: return sorted.filter { $0.status == .declined }
        case .completed: return sorted.filter { $0.status == .completed }
        }
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Incoming Requests")
                        .font(.largeTitle.bold())
                        .foregroundStyle(.white)
                        .padding(.top, 8)

                    Picker("Filter", selection: $filter) {
                        ForEach(Filter.allCases) { f in
                            Text(f.title).tag(f)
                        }
                    }
                    .pickerStyle(.segmented)

                    if let message {
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.75))
                    }

                    if isLoading {
                        LuxuryCard { ProgressView().tint(Lx.gold) }
                    }

                    if filteredRequests.isEmpty && !isLoading {
                        LuxuryCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(requests.isEmpty ? "No custom requests yet" : "No requests for this filter")
                                    .font(.headline)
                                Text(requests.isEmpty ? "You'll see traveler requests here when they contact you directly." : "Try a different filter.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } else {
                        ForEach(filteredRequests) { req in
                            requestRow(req)
                        }
                    }

                    Spacer(minLength: 12)
                }
                .padding(18)
            }
        }
        .navigationTitle("Requests")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .refreshable { await load() }
    }

    @ViewBuilder
    private func requestRow(_ req: CustomRequest) -> some View {
        LuxuryCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Text(req.title ?? "Custom request")
                        .font(.headline)
                    Spacer()
                    LuxuryPill(text: req.status.rawValue.capitalized)
                }
                if let msg = req.message, !msg.isEmpty {
                    Text(msg).foregroundStyle(.secondary)
                }

                HStack(spacing: 8) {
                    if let city = req.city, !city.isEmpty {
                        Label(city, systemImage: "mappin.and.ellipse")
                    }
                    if let country = req.country, !country.isEmpty {
                        Text(country)
                    }
                    Spacer()
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                HStack(spacing: 12) {
                    if let d = req.preferredDate {
                        Label(format(date: d), systemImage: "calendar")
                    }
                    if let b = req.budget {
                        Label("\(formatCurrency(b))", systemImage: "creditcard")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                HStack {
                    if req.status == .pending {
                        Button {
                            Task { await setStatus(req, .accepted) }
                        } label: { Text("Accept") }
                        .buttonStyle(LuxuryPrimaryButtonStyle())

                        Button {
                            Task { await setStatus(req, .declined) }
                        } label: { Text("Decline") }
                        .buttonStyle(LuxurySecondaryButtonStyle())
                    } else if req.status == .accepted {
                        Button {
                            Task { await setStatus(req, .completed) }
                        } label: { Text("Mark completed") }
                        .buttonStyle(LuxurySecondaryButtonStyle())
                    }
                    Spacer()
                }
                .padding(.top, 4)
            }
        }
    }

    private func load() async {
        guard let email = appState.session.currentUser?.email?.lowercased(), !email.isEmpty else {
            await MainActor.run { message = "Not signed in." }
            return
        }
        isLoading = true
        message = nil
        do {
            let list = try await FirestoreService.shared.listCustomRequestsForProvider(providerEmail: email)
            await MainActor.run {
                requests = list.sorted { ($0.createdAt) > ($1.createdAt) }
            }
        } catch {
            await MainActor.run { message = error.localizedDescription }
        }
        isLoading = false
    }

    private func setStatus(_ req: CustomRequest, _ status: CustomRequest.Status) async {
        do {
            try await FirestoreService.shared.updateCustomRequest(
                requestId: req.id,
                fields: [
                    "status": status.rawValue,
                    "updatedAt": Date()
                ]
            )
            await load()
            Haptics.success()
        } catch {
            await MainActor.run { message = error.localizedDescription }
        }
    }

    private func format(date: Date) -> String {
        let df = DateFormatter()
        df.dateStyle = .medium
        return df.string(from: date)
    }

    private func formatCurrency(_ value: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "RON"
        return f.string(from: NSNumber(value: value)) ?? String(format: "%.0f RON", value)
    }
}

