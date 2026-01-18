import SwiftUI

/// Floating language switcher available throughout the app.
///
/// It updates local UI language immediately and (if signed in) persists
/// the preference to the user's Firestore profile (`preferredLanguageCode`).
struct LanguageSwitcherOverlay: View {
    @EnvironmentObject var appState: AppState

    private var current: String {
        appState.settings.languageCode.lowercased().hasPrefix("ro") ? "ro" : "en"
    }

    var body: some View {
        Menu {
            Button {
                setLanguage("en")
            } label: {
                HStack {
                    Text("English")
                    Spacer()
                    if current == "en" { Image(systemName: "checkmark") }
                }
            }

            Button {
                setLanguage("ro")
            } label: {
                HStack {
                    Text("Română")
                    Spacer()
                    if current == "ro" { Image(systemName: "checkmark") }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "globe")
                Text(current.uppercased())
                    .font(.caption.weight(.semibold))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(.black.opacity(0.55))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Lx.gold.opacity(0.25), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .foregroundStyle(.white)
        }
        .accessibilityLabel("Language")
    }

    private func setLanguage(_ code: String) {
        appState.settings.setLanguage(code)
        // Persist to profile if we have a user
        if let uid = appState.session.currentUser?.id {
            Task {
                try? await FirestoreService.shared.updateUser(uid: uid, fields: [
                    "preferredLanguageCode": code
                ])
            }
        }
    }
}
