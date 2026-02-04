import SwiftUI

struct GoogleSignInButtonView: View {
    var isLoading: Bool = false
    var onTap: () -> Void

    var body: some View {
        Button {
            onTap()
        } label: {
            HStack(spacing: 10) {
                logo
                Text(isLoading ? "Signing in..." : "Sign in with Google")
                    .font(.headline)
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 48)
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.black.opacity(0.75))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.14), lineWidth: 1)
        )
        .overlay(innerGlow)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .opacity(isLoading ? 0.9 : 1.0)
        .overlay {
            if isLoading {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.black.opacity(0.45))
                ProgressView().tint(.white)
            }
        }
        .disabled(isLoading)
        .accessibilityLabel("Sign in with Google")
    }

    private var innerGlow: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .stroke(Color.white.opacity(0.18), lineWidth: 1)
            .blur(radius: 1.5)
            .mask(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.black)
            )
            .padding(1)
    }

    private var logo: some View {
        let gradient = LinearGradient(
            colors: [
                Color(red: 0.26, green: 0.52, blue: 0.96), // blue
                Color(red: 0.91, green: 0.26, blue: 0.22), // red
                Color(red: 0.95, green: 0.74, blue: 0.18), // yellow
                Color(red: 0.13, green: 0.67, blue: 0.38)  // green
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        return Text("G")
            .font(.headline.weight(.bold))
            .foregroundStyle(gradient)
            .frame(width: 24, height: 24)
            .background(
                Circle().fill(Color.white.opacity(0.10))
            )
    }
}
