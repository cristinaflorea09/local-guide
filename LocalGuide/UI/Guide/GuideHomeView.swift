import SwiftUI

struct GuideHomeView: View {
    @EnvironmentObject var appState: AppState

    private var isApproved: Bool {
        (appState.session.currentUser?.guideApproved ?? false) == true
    }

    var body: some View {
        TabView {
            GuideGateView()
                .tabItem { Label("Home", systemImage: "house") }

            NavigationStack {
                if isApproved { GuideToursView() }
                else { NotApprovedView() }
            }
            .tabItem { Label("Tours", systemImage: "map") }

            NavigationStack {
                if isApproved { GuideAvailabilityView() }
                else { NotApprovedView() }
            }
            .tabItem { Label("Availability", systemImage: "calendar.badge.plus") }

            NavigationStack {
                if isApproved { ChatsListView(mode: .guide) }
                else { NotApprovedView() }
            }
            .tabItem { Label("Chat", systemImage: "message") }
            NavigationStack {
                AccountView()
            }
            .tabItem { Label("Account", systemImage: "map") }
            NavigationStack {
                if isApproved { GuideBookingsView() }
                else { NotApprovedView() }
            }
            .tabItem { Label("Bookings", systemImage: "calendar") }

            NavigationStack {
                GuideProfileEditView()
            }
            .tabItem { Label("Profile", systemImage: "person.crop.circle") }
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
