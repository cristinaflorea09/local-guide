import SwiftUI

@MainActor
final class AppSettings: ObservableObject {
    @AppStorage("appLanguageCode") var languageCode: String = "en"
}
