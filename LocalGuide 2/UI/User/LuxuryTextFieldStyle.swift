// LuxuryTextFieldStyle.swift
// Provides a custom text field style used across the app

import SwiftUI

public struct LuxuryTextFieldStyle: TextFieldStyle {
    public init() {}

    public func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
            )
            .foregroundStyle(.white)
    }
}

// Convenience modifier to apply the style more succinctly if desired
public extension View {
    func luxuryTextFieldStyle() -> some View {
        self.textFieldStyle(LuxuryTextFieldStyle())
    }
}
