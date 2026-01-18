import SwiftUI

struct AdminModerationView: View {
    @EnvironmentObject var appState: AppState
    @State private var reports: [FeedReport] = []
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Moderation")
                            .font(.largeTitle.bold())
                            .foregroundStyle(.white)

                        if isLoading { ProgressView().tint(Lx.gold) }

                        ForEach(reports) { r in
                            LuxuryCard {
                                VStack(alignment: .leading, spacing: 10) {
                                    HStack {
                                        Text("\(r.targetType.rawValue.uppercased())")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(Lx.gold)
                                        Spacer()
                                        Text(r.createdAt.formatted(date: .abbreviated, time: .shortened))
                                            .font(.caption)
                                            .foregroundStyle(.white.opacity(0.6))
                                    }
                                    Text(r.reason)
                                        .foregroundStyle(.white.opacity(0.85))
                                    HStack {
                                        Button("Hide") {
                                            Task { await hide(r) }
                                        }
                                        .buttonStyle(LuxurySecondaryButtonStyle())
                                        Button("Resolve") {
                                            Task { await resolve(r) }
                                        }
                                        .buttonStyle(LuxuryPrimaryButtonStyle())
                                    }
                                }
                            }
                        }

                        Spacer(minLength: 16)
                    }
                    .padding(18)
                }
            }
            .task { await reload() }
            .refreshable { await reload() }
        }
    }

    private func reload() async {
        isLoading = true
        defer { isLoading = false }
        do {
            reports = try await FirestoreService.shared.listReports(limit: 200)
        } catch {
            reports = []
        }
    }

    private func hide(_ r: FeedReport) async {
        do {
            if r.targetType == .post {
                try await FirestoreService.shared.hidePost(postId: r.targetId)
            } else {
                try await FirestoreService.shared.hideComment(commentId: r.targetId)
            }
            await resolve(r)
        } catch { }
    }

    private func resolve(_ r: FeedReport) async {
        guard let adminId = appState.session.firebaseUser?.uid else { return }
        do {
            try await FirestoreService.shared.resolveReport(reportId: r.id, adminId: adminId)
            reports.removeAll { $0.id == r.id }
        } catch { }
    }
}
