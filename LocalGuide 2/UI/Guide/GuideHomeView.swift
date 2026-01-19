import SwiftUI

struct GuideHomeView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var chatUnread: ChatUnreadService

    private var isApproved: Bool {
        (appState.session.currentUser?.guideApproved ?? false) == true
    }

    var body: some View {
        TabView(selection: $appState.guideTab) {
            // First 4 tabs (always visible). Keep aligned with Host.
            GuideGateView()
                .tabItem { Label("Home", systemImage: "house") }
                .tag(0)

            NavigationStack {
                if isApproved { GuideToursView() }
                else { NotApprovedView() }
            }
            .tabItem { Label("Tours", systemImage: "map") }
            .tag(1)

            NavigationStack {
                if isApproved { GuideBookingsView() }
                else { NotApprovedView() }
            }
            .tabItem { Label("Bookings", systemImage: "calendar") }
            .tag(2)

            NavigationStack {
                if isApproved { SellerCampaignsView() }
                else { NotApprovedView() }
            }
            .tabItem { Label("Campaigns", systemImage: "tag.fill") }
            .tag(3)

            // Tabs below will appear under iOS "More". Keep alphabetical and consistent across roles.
            NavigationStack { AccountView() }
                .tabItem { Label("Account", systemImage: "person") }
                .tag(4)

            NavigationStack {
                if isApproved { GuideAvailabilityView() }
                else { NotApprovedView() }
            }
            .tabItem { Label("Availability", systemImage: "calendar.badge.plus") }
            .tag(5)

            NavigationStack {
                if isApproved { ChatsListView(mode: .seller) }
                else { NotApprovedView() }
            }
            .tabItem { Label("Chat", systemImage: "message") }
            .badge(chatUnread.unreadCount == 0 ? 0 : chatUnread.unreadCount)
            .tag(6)

            NavigationStack { CommunityFeedView() }
                .tabItem { Label("Community", systemImage: "newspaper") }
                .tag(7)

            NavigationStack { SellerEarningsDashboardView() }
                .tabItem { Label("Earnings", systemImage: "chart.line.uptrend.xyaxis") }
                .tag(8)

            NavigationStack { GuideProfileEditView() }
                .tabItem { Label("Profile", systemImage: "person.crop.circle") }
                .tag(9)

            NavigationStack { SettingsView() }
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(10)
        }
    }
}

private struct NotApprovedView: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 12) {
                Image(systemName: "lock.fill")
                    .font(.title2)
                    .foregroundStyle(Lx.gold)
                Text("Pending approval")
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                Text("This section will unlock once your guide account is approved.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.horizontal, 22)
            }
        }
    }
}
