import SwiftUI

struct AdminHomeView: View {
    var body: some View {
        TabView {
            AdminUsersView()
                .tabItem { Label("Users", systemImage: "person.3") }

            AdminGuidesView()
                .tabItem { Label("Guides", systemImage: "person.badge.checkmark") }

            AdminStatsView()
                .tabItem { Label("Stats", systemImage: "chart.bar") }

            AccountView()
                .tabItem { Label("Account", systemImage: "person") }
        }
    }
}
