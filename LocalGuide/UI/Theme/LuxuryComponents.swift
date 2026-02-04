import SwiftUI

struct LuxuryCard<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }

    var body: some View {
        content
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: Lx.radius, style: .continuous)
                    .fill(.thinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Lx.radius, style: .continuous)
                    .stroke(Lx.gold.opacity(0.18), lineWidth: 1)
            )
            .shadow(color: Lx.shadow, radius: 12, x: 0, y: 8)
    }
}

struct LuxuryPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Lx.gold)
            )
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
    }
}

struct LuxurySecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.10))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Lx.gold.opacity(0.22), lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.99 : 1.0)
    }
}

struct LuxuryPill: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Capsule().fill(Lx.gold.opacity(0.16)))
            .overlay(Capsule().stroke(Lx.gold.opacity(0.25), lineWidth: 1))
    }
}

struct LuxuryTextField: View {
    let title: String
    @Binding var text: String
    var secure: Bool = false
    var keyboard: UIKeyboardType = .default
    var identifier: String? = nil
    
    // For password fields, allow toggling visibility with an eye button.
    @State private var isRevealed: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            HStack(spacing: 10) {
                if secure {
                    if isRevealed {
                        textFieldView(TextField("", text: $text))
                            .keyboardType(keyboard)
                            .textInputAutocapitalization(.never)
                    } else {
                        textFieldView(SecureField("", text: $text))
                            .keyboardType(keyboard)
                            .textInputAutocapitalization(.never)
                    }

                    Button {
                        isRevealed.toggle()
                        Haptics.light()
                    } label: {
                        Image(systemName: isRevealed ? "eye.slash" : "eye")
                            .foregroundStyle(.white.opacity(0.8))
                            .padding(.leading, 6)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(isRevealed ? "Hide password" : "Show password")
                } else {
                    textFieldView(TextField("", text: $text))
                        .keyboardType(keyboard)
                        .textInputAutocapitalization(.never)
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Lx.gold.opacity(0.16), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func textFieldView<T: View>(_ field: T) -> some View {
        if let identifier {
            field.accessibilityIdentifier(identifier)
        } else {
            field
        }
    }
}
