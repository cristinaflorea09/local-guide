import SwiftUI

struct HostHomeView: View {
    var body: some View {
        TabView {
            GuideToursView()
                .tabItem { Label("Experiences", systemImage: "sparkles") }

            GuideBookingsView()
                .tabItem { Label("Bookings", systemImage: "calendar") }

            GuideAvailabilityView()
                .tabItem { Label("Availability", systemImage: "clock") }

            ChatsListView(mode: .guide)
                .tabItem { Label("Chat", systemImage: "message.fill") }

            AccountView()
                .tabItem { Label("Account", systemImage: "person.fill") }
        }
    }
}
