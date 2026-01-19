import SwiftUI

/// Admin screen to approve Guides (attestation) and Hosts (SRL/PFA compliance).
struct AdminApprovalsView: View {
    @State private var tab: Tab = .guides

    @State private var guideItems: [FirestoreService.PendingGuideAttestation] = []
    @State private var hostItems: [FirestoreService.PendingHostCompliance] = []
    @State private var isLoading = false
    @State private var message: String?

    @State private var showRejectPrompt = false
    @State private var rejectNote: String = ""
    @State private var rejectTarget: RejectTarget?

    enum Tab: String, CaseIterable, Identifiable {
        case guides
        case hosts
        var id: String { rawValue }
    }

    struct RejectTarget {
        let uid: String
        let kind: Tab
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 12) {
                    Picker("", selection: $tab) {
                        Text("admin_guides").tag(Tab.guides)
                        Text("admin_hosts").tag(Tab.hosts)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    if let message {
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.75))
                            .padding(.horizontal)
                    }

                    List {
                        switch tab {
                        case .guides:
                            ForEach(guideItems) { item in
                                guideRow(item)
                                    .listRowBackground(Color.black)
                            }
                        case .hosts:
                            ForEach(hostItems) { item in
                                hostRow(item)
                                    .listRowBackground(Color.black)
                            }
                        }
                    }
                    .scrollContentBackground(.hidden)
                }

                if isLoading {
                    ProgressView().tint(Lx.gold)
                }
            }
            .navigationTitle("admin_approvals")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
            }
            .task { await load() }
            .onChange(of: tab) { _ in
                Task { await load() }
            }
            .alert("admin_reject_title", isPresented: $showRejectPrompt) {
                TextField("admin_reject_reason_optional", text: $rejectNote)
                Button("admin_reject", role: .destructive) {
                    guard let target = rejectTarget else { return }
                    Task {
                        await reject(uid: target.uid, kind: target.kind, note: rejectNote.isEmpty ? nil : rejectNote)
                    }
                }
                Button("common_cancel", role: .cancel) { }
            } message: {
                Text("admin_reject_message_keep_account")
            }
        }
    }

    // MARK: Rows

    @ViewBuilder
    private func guideRow(_ item: FirestoreService.PendingGuideAttestation) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            header(title: item.profile.displayName, subtitle: item.user.email ?? "", badgeKey: "admin_pending")

            Text("\(item.profile.country), \(item.profile.city)")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.7))

            if let urlStr = item.profile.attestationURL, let url = URL(string: urlStr) {
                Link("admin_view_attestation", destination: url)
                    .foregroundStyle(Lx.gold)
                    .font(.subheadline.weight(.semibold))
            }

            actionButtons(uid: item.id, kind: .guides)
        }
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private func hostRow(_ item: FirestoreService.PendingHostCompliance) -> some View {
        let title = item.profile?.brandName.isEmpty == false ? (item.profile?.brandName ?? "") : (item.user.fullName)
        VStack(alignment: .leading, spacing: 10) {
            header(title: title, subtitle: item.user.email ?? "", badgeKey: "admin_pending")

            Text([item.user.businessType, item.user.businessName].compactMap { $0 }.joined(separator: " • "))
                .font(.caption)
                .foregroundStyle(.white.opacity(0.7))

            if let urlStr = item.user.businessCertificateURL, let url = URL(string: urlStr) {
                Link("admin_view_certificate", destination: url)
                    .foregroundStyle(Lx.gold)
                    .font(.subheadline.weight(.semibold))
            }

            actionButtons(uid: item.id, kind: .hosts)
        }
        .padding(.vertical, 6)
    }

    private func header(title: String, subtitle: String, badgeKey: String) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.65))
                }
            }
            Spacer()
            Text(badgeKey)
                .font(.caption.weight(.bold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Lx.gold.opacity(0.12))
                .foregroundStyle(Lx.gold)
                .clipShape(Capsule())
        }
    }

    private func actionButtons(uid: String, kind: Tab) -> some View {
        HStack(spacing: 10) {
            Button {
                Task { await approve(uid: uid, kind: kind) }
            } label: {
                Text("admin_approve")
            }
            .buttonStyle(LuxuryPrimaryButtonStyle())

            Button {
                rejectTarget = RejectTarget(uid: uid, kind: kind)
                rejectNote = ""
                showRejectPrompt = true
            } label: {
                Text("admin_reject")
            }
            .buttonStyle(LuxurySecondaryButtonStyle())
        }
    }

    // MARK: Data

    private func load() async {
        isLoading = true
        message = nil
        do {
            switch tab {
            case .guides:
                guideItems = try await FirestoreService.shared.listPendingGuideAttestations()
                if guideItems.isEmpty { message = "admin_no_pending" }
            case .hosts:
                hostItems = try await FirestoreService.shared.listPendingHostCompliance()
                if hostItems.isEmpty { message = "admin_no_pending" }
            }
        } catch {
            message = error.localizedDescription
        }
        isLoading = false
    }

    private func approve(uid: String, kind: Tab) async {
        isLoading = true
        do {
            switch kind {
            case .guides:
                try await FirestoreService.shared.setGuideApprovalStatus(uid: uid, approved: true)
                guideItems.removeAll { $0.id == uid }
            case .hosts:
                try await FirestoreService.shared.setHostApprovalStatus(uid: uid, approved: true)
                hostItems.removeAll { $0.id == uid }
            }
            message = "admin_action_done"
        } catch {
            message = error.localizedDescription
        }
        isLoading = false
    }

    private func reject(uid: String, kind: Tab, note: String?) async {
        isLoading = true
        do {
            switch kind {
            case .guides:
                try await FirestoreService.shared.setGuideApprovalStatus(uid: uid, approved: false, note: note)
                guideItems.removeAll { $0.id == uid }
            case .hosts:
                try await FirestoreService.shared.setHostApprovalStatus(uid: uid, approved: false, note: note)
                hostItems.removeAll { $0.id == uid }
            }
            message = "admin_action_done"
        } catch {
            message = error.localizedDescription
        }
        isLoading = false
    }
}
