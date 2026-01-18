import SwiftUI

struct HostHomeView: View {
    @EnvironmentObject var chatUnread: ChatUnreadService

    var body: some View {
        TabView {
            HostGateView()
                .tabItem { Label("Home", systemImage: "house") }

            HostExperiencesView()
                .tabItem { Label("Experiences", systemImage: "sparkles") }

            HostBookingsView()
                .tabItem { Label("Bookings", systemImage: "calendar") }

            NavigationStack {
                SellerCampaignsView()
            }
            .tabItem { Label("Campaigns", systemImage: "tag.fill") }

            GuideAvailabilityView()
                .tabItem { Label("Availability", systemImage: "clock") }

            ChatsListView(mode: .seller)
                .tabItem { Label("Chat", systemImage: "message.fill") }
                .badge(chatUnread.unreadCount == 0 ? 0 : chatUnread.unreadCount)

            NavigationStack {
                CommunityFeedView()
            }
            .tabItem { Label("Community", systemImage: "newspaper") }

            AccountView()
                .tabItem { Label("Account", systemImage: "person.fill") }

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }

            NavigationStack {
                SellerEarningsDashboardView()
            }
            .tabItem { Label("Earnings", systemImage: "chart.line.uptrend.xyaxis") }
        }
    }
}
