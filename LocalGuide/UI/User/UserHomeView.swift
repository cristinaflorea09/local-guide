import SwiftUI

struct UserHomeView: View {
    @EnvironmentObject var chatUnread: ChatUnreadService

    var body: some View {
        TabView {
            UserDashboardView()
                .tabItem { Label("Home", systemImage: "house") }

            ExploreMarketplaceView()
                .tabItem { Label("Tours/Experiences", systemImage: "magnifyingglass") }

            TripPlannerView()
                .tabItem { Label("Plan", systemImage: "sparkles") }

            GoogleMapToursView()
                .tabItem { Label("Map", systemImage: "map") }

            UserBookingsView()
                .tabItem { Label("Bookings", systemImage: "ticket") }

            ChatsListView(mode: .traveler)
                .tabItem { Label("Chat", systemImage: "message") }
                .badge(chatUnread.unreadCount == 0 ? 0 : chatUnread.unreadCount)

            CommunityFeedView()
                .tabItem { Label("Community", systemImage: "newspaper") }

            SubscriptionView()
                .tabItem { Label("Premium", systemImage: "crown") }

            AccountView()
                .tabItem { Label("Account", systemImage: "person.fill") }

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
    }
}
