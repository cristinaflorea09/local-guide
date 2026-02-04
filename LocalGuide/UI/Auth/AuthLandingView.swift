import SwiftUI

struct AuthLandingView: View {
    @EnvironmentObject var router: AuthRouter

    var body: some View {
        ZStack {
            // Background "image" layer. Add an asset named `landing_bg` for best results.
            Group {
                if UIImage(named: "landing_bg") != nil {
                    Image("landing_bg")
                        .resizable()
                        .scaledToFill()
                        .ignoresSafeArea()
                        .overlay(Color.black.opacity(0.55))
                } else {
                    LinearGradient(colors: [Color.black, Color.black.opacity(0.92), Color.black.opacity(0.86)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                        .ignoresSafeArea()

                    // Subtle pattern to hint "maps + experiences"
                    ZStack {
                        Image(systemName: "map.fill")
                            .font(.system(size: 220))
                            .foregroundStyle(Lx.gold.opacity(0.08))
                            .blur(radius: 0.5)
                            .offset(x: 120, y: -160)

                        Image(systemName: "figure.walk")
                            .font(.system(size: 180))
                            .foregroundStyle(.white.opacity(0.05))
                            .offset(x: -130, y: 160)

                        Image(systemName: "sparkles")
                            .font(.system(size: 120))
                            .foregroundStyle(Lx.gold.opacity(0.06))
                            .offset(x: -140, y: -80)
                    }
                }
            }

            VStack(spacing: 18) {
                Spacer()

                VStack(spacing: 10) {
                    Text("LOCALGUIDE")
                        .font(.system(size: 44, weight: .black, design: .serif))
                        .tracking(3)
                        .foregroundStyle(Lx.gold)

                    Text("Luxury local experiences by independent Guides & Hosts")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.75))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 18)
                }

                LuxuryCard {
                    VStack(spacing: 12) {
                        Button { router.path = [.rolePicker] } label: { Text("Create account") }
                            .buttonStyle(LuxuryPrimaryButtonStyle())
                            .accessibilityIdentifier("auth_create_account")

                        Button { router.goToLogin() } label: { Text("Login") }
                            .buttonStyle(LuxurySecondaryButtonStyle())
                            .accessibilityIdentifier("auth_login")
                    }
                }
                .padding(.horizontal, 18)

                Spacer()

                Text("By continuing you agree to our Terms & Conditions.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.55))
                    .padding(.bottom, 10)
            }
        }
    }
}
