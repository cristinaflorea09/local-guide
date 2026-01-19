import SwiftUI

struct AdminHomeView: View {
    var body: some View {
        TabView {
            AdminUsersView()
                .tabItem {
                    Image(systemName: "person.3")
                    Text("Users")
                }

            AdminGuidesView()
                .tabItem {
                    Image(systemName: "person.badge.checkmark")
                    Text("Guides")
                }

            AdminApprovalsView()
                .tabItem {
                    Image(systemName: "checkmark.seal")
                    Text("Approvals")
                }

            AdminModerationView()
                .tabItem {
                    Image(systemName: "shield.lefthalf.filled")
                    Text("Moderation")
                }

            AdminStatsView()
                .tabItem {
                    Image(systemName: "chart.bar")
                    Text("Stats")
                }

            AdminFinanceView()
                .tabItem {
                    Image(systemName: "creditcard")
                    Text("Finance")
                }

            AccountView()
                .tabItem {
                    Image(systemName: "person")
                    Text("Account")
                }

            SettingsView()
                .tabItem {
                    Image(systemName: "gearshape")
                    Text("Settings")
                }
        }
    }
}
