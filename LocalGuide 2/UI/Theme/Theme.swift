import SwiftUI

enum Lx {
    static let gold = Color("LxGold", bundle: .main, fallback: Color(red: 0.82, green: 0.70, blue: 0.34))
    static let shadow = Color.black.opacity(0.22)
    static let radius: CGFloat = 18
}

extension Color {
    init(_ name: String, bundle: Bundle?, fallback: Color) {
        if let ui = UIColor(named: name, in: bundle, compatibleWith: nil) {
            self = Color(ui)
        } else {
            self = fallback
        }
    }
}
