import SwiftUI

struct UserHomeView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        TabView {
            ExploreToursView()
                .tabItem { Label("Explore", systemImage: "magnifyingglass") }

            MapToursView()
                .tabItem { Label("Map", systemImage: "map") }

            ChatsListView(mode: .user)
                .tabItem { Label("Chat", systemImage: "message") }
UserBookingsView()
                .tabItem { Label("Bookings", systemImage: "ticket") }

            SubscriptionView()
                .tabItem { Label("Premium", systemImage: "crown") }

            AccountView()
                .tabItem { Label("Account", systemImage: "person") }
        }
    }
}
