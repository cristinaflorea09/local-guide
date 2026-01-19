import SwiftUI

struct UserHomeView: View {
    @EnvironmentObject var chatUnread: ChatUnreadService
    @EnvironmentObject var appState: AppState

    var body: some View {
        TabView(selection: $appState.travelerTab) {
            UserDashboardView()
                .tabItem { Label("Home", systemImage: "house") }
                .tag(0)

            ExploreMarketplaceView()
                .tabItem { Label("Tours/Experiences", systemImage: "magnifyingglass") }
                .tag(1)

            TripPlannerView()
                .tabItem { Label("Plan", systemImage: "sparkles") }
                .tag(2)

            GoogleMapToursView()
                .tabItem { Label("Map", systemImage: "map") }
                .tag(3)

            // Tabs below will appear under iOS "More". Keep alphabetical.
            AccountView()
                .tabItem { Label("Account", systemImage: "person.fill") }
                .tag(4)

            UserBookingsView()
                .tabItem { Label("Bookings", systemImage: "ticket") }
                .tag(5)

            ChatsListView(mode: .traveler)
                .tabItem { Label("Chat", systemImage: "message") }
                .badge(chatUnread.unreadCount == 0 ? 0 : chatUnread.unreadCount)
                .tag(6)

            CommunityFeedView()
                .tabItem { Label("Community", systemImage: "newspaper") }
                .tag(7)

            SubscriptionView()
                .tabItem { Label("Premium", systemImage: "crown") }
                .tag(8)

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(9)
        }
    }
}
