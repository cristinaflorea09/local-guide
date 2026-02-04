import SwiftUI

struct AccountView: View {
    @EnvironmentObject var appState: AppState
    @State private var showSellerPlans = false
    @State private var showCustomRequestForm = false
    @State private var showProviderRequests = false
    @State private var showCustomRequestDirectory = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 14) {
                Text("Account")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.white)

                if let user = appState.session.currentUser {
                    LuxuryCard {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("Name")
                                Spacer()
                                Text(user.fullName).foregroundStyle(.secondary)
                            }
                            HStack {
                                Text("Role")
                                Spacer()
                                LuxuryPill(text: user.role.rawValue.uppercased())
                            }

                            HStack {
                                Text("Plan")
                                Spacer()
                                Text(user.subscriptionPlan == .premium ? "Premium" : "Free (ads)")
                                    .foregroundStyle(.secondary)
                            }
                            if !appState.subscription.isPremium && user.subscriptionPlan == .premium {
                                Text("Premium selected — purchase in Premium tab.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    if user.role == .traveler {
                        NavigationLink { UserProfileEditView() } label: { Text("Edit Profile") }
                            .buttonStyle(LuxurySecondaryButtonStyle())
                    }
                    if user.role == .guide {
                        NavigationLink { GuideProfileEditView() } label: { Text("Edit Guide Profile") }
                            .buttonStyle(LuxurySecondaryButtonStyle())
                    }

                    NavigationLink { SubscriptionView() } label: { Text("Premium") }
                        .buttonStyle(LuxurySecondaryButtonStyle())

                    if user.role == .guide || user.role == .host {
                        Button {
                            showSellerPlans = true
                        } label: {
                            Text("Seller Plans")
                        }
                        .buttonStyle(LuxurySecondaryButtonStyle())
                    }

                    LuxuryCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Custom requests").font(.headline)
                            if user.role == .traveler {
                                Button { showCustomRequestForm = true } label: { Text("Request a custom tour/experience") }
                                    .buttonStyle(LuxurySecondaryButtonStyle())
                            }
                            if user.role == .traveler {
                                Button { showCustomRequestDirectory = true } label: { Text("Find providers who accept custom requests") }
                                    .buttonStyle(LuxurySecondaryButtonStyle())
                            }
                            if user.role == .guide || user.role == .host {
                                Button { showProviderRequests = true } label: { Text("View incoming requests") }
                                    .buttonStyle(LuxurySecondaryButtonStyle())
                            }
                        }
                    }
                }

                Button { appState.session.signOut() } label: { Text("Sign Out") }
                    .buttonStyle(LuxurySecondaryButtonStyle())

                Spacer()
            }
            .padding(18)
        }
        .fullScreenCover(isPresented: $showSellerPlans) {
            NavigationStack {
                SellerPlansView()
                    .environmentObject(appState)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button {
                                showSellerPlans = false
                            } label: {
                                Image(systemName: "chevron.left")
                            }
                        }
                    }
            }
        }
        .fullScreenCover(isPresented: $showCustomRequestForm) {
            NavigationStack {
                CustomRequestFormView(prefilledProviderEmail: nil)
                    .environmentObject(appState)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) { Button { showCustomRequestForm = false } label: { Image(systemName: "chevron.left") } }
                    }
            }
        }
        .fullScreenCover(isPresented: $showProviderRequests) {
            NavigationStack {
                ProviderCustomRequestsView()
                    .environmentObject(appState)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) { Button { showProviderRequests = false } label: { Image(systemName: "chevron.left") } }
                    }
            }
        }
        .fullScreenCover(isPresented: $showCustomRequestDirectory) {
            NavigationStack {
                CustomRequestDirectoryView()
                    .environmentObject(appState)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) { Button { showCustomRequestDirectory = false } label: { Image(systemName: "chevron.left") } }
                    }
            }
        }
    }
}

