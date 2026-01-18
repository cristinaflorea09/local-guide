import SwiftUI
import Combine

/// Global app settings.
///
/// - Keeps `languageCode` as `@Published` so SwiftUI updates across the entire app.
/// - Persists to `@AppStorage`.
/// - Calls `Bundle.setAppLanguage` so localized strings swap without restart.
@MainActor
final class AppSettings: ObservableObject {

    @AppStorage("appLanguageCode") private var storedLanguageCode: String = "en"

    /// Current language code ("en" or "ro").
    @Published var languageCode: String = "en"

    private var defaultsObserver: NSObjectProtocol?

    init() {
        let initial = storedLanguageCode.lowercased().hasPrefix("ro") ? "ro" : "en"
        languageCode = initial
        Bundle.setAppLanguage(initial)

        // Keep in sync if UserDefaults changes (rare, but possible).
        defaultsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            let v = self.storedLanguageCode.lowercased().hasPrefix("ro") ? "ro" : "en"
            if self.languageCode != v {
                self.languageCode = v
                Bundle.setAppLanguage(v)
            }
        }
    }

    deinit {
        if let defaultsObserver {
            NotificationCenter.default.removeObserver(defaultsObserver)
        }
    }

    func setLanguage(_ code: String) {
        let normalized = code.lowercased().hasPrefix("ro") ? "ro" : "en"
        guard !(normalized == languageCode && normalized == storedLanguageCode) else {
            Bundle.setAppLanguage(normalized)
            return
        }
        languageCode = normalized
        storedLanguageCode = normalized
        Bundle.setAppLanguage(normalized)
    }
}
