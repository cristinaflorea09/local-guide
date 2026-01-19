import SwiftUI

struct HostHomeView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var chatUnread: ChatUnreadService

    var body: some View {
        TabView(selection: $appState.hostTab) {
            // First 4 tabs (always visible). Keep aligned with Guide.
            HostGateView()
                .tabItem { Label("Home", systemImage: "house") }
                .tag(0)

            HostExperiencesView()
                .tabItem { Label("Experiences", systemImage: "sparkles") }
                .tag(1)

            HostBookingsView()
                .tabItem { Label("Bookings", systemImage: "calendar") }
                .tag(2)

            NavigationStack { SellerCampaignsView() }
                .tabItem { Label("Campaigns", systemImage: "tag.fill") }
                .tag(3)

            // Tabs below will appear under iOS "More". Keep alphabetical and consistent across roles.
            NavigationStack { AccountView() }
                .tabItem { Label("Account", systemImage: "person") }
                .tag(4)

            NavigationStack { HostAvailabilityView() }
                .tabItem { Label("Availability", systemImage: "calendar.badge.plus") }
                .tag(5)

            ChatsListView(mode: .seller)
                .tabItem { Label("Chat", systemImage: "message") }
                .badge(chatUnread.unreadCount == 0 ? 0 : chatUnread.unreadCount)
                .tag(6)

            NavigationStack { CommunityFeedView() }
                .tabItem { Label("Community", systemImage: "newspaper") }
                .tag(7)

            NavigationStack { SellerEarningsDashboardView() }
                .tabItem { Label("Earnings", systemImage: "chart.line.uptrend.xyaxis") }
                .tag(8)

            NavigationStack { HostProfileEditView() }
                .tabItem { Label("Profile", systemImage: "person.crop.circle") }
                .tag(9)

            NavigationStack { SettingsView() }
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(10)
        }
    }
}
