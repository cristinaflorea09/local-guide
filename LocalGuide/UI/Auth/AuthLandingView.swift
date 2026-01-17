import SwiftUI

struct AuthLandingView: View {
    @EnvironmentObject var router: AuthRouter

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color.black, Color.black.opacity(0.92), Color.black.opacity(0.86)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()

            VStack(spacing: 18) {
                Spacer()

                VStack(spacing: 10) {
                    Text("LOCALGUIDE")
                        .font(.system(size: 44, weight: .black, design: .rounded))
                        .tracking(3.5)
                        .foregroundStyle(
                            LinearGradient(colors: [Lx.gold, .white.opacity(0.85), Lx.gold.opacity(0.8)],
                                           startPoint: .topLeading, endPoint: .bottomTrailing)
                        )

                    Text("Luxury local experiences, curated by trusted hosts & guides.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.75))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 22)
                }

                LuxuryCard {
                    VStack(spacing: 12) {
                        Button { router.path = [.rolePicker] } label: { Text("Create account") }
                            .buttonStyle(LuxuryPrimaryButtonStyle())

                        Button { router.goToLogin() } label: { Text("Login") }
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
