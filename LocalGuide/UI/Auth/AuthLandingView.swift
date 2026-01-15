import SwiftUI

struct AuthLandingView: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color.white, Color.black.opacity(0.92), Color.black.opacity(0.86)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()

            VStack(spacing: 18) {
                Spacer()

                VStack(spacing: 10) {
                    Text(AppConfig.appName)
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text("Luxury local experiences, curated by trusted guides.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.75))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 22)
                }

                LuxuryCard {
                    VStack(spacing: 12) {
                        NavigationLink { RolePickerView() } label: { Text("Create account") }
                            .buttonStyle(LuxuryPrimaryButtonStyle())

                        NavigationLink { LoginView() } label: { Text("Login") }
                            .buttonStyle(LuxurySecondaryButtonStyle())
                    }
                }
                .padding(.horizontal, 18)

                Spacer()

                Text("By continuing you agree to our Terms & Privacy Policy.")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.55))
                    .padding(.bottom, 10)
            }
            .padding(.top, 12)
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}
