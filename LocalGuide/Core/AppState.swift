import Foundation
import Combine

@MainActor
final class AppState: ObservableObject {
    var settings = AppSettings()
    @Published var session = SessionManager()
    @Published var subscription = SubscriptionManager()

    // Tab selections (bound to TabView(selection:)).
    // This lets us programmatically switch to a tab when a user taps a card
    // that navigates to a screen that also exists as a dedicated tab.
    @Published var travelerTab: Int = 0
    @Published var guideTab: Int = 0
    @Published var hostTab: Int = 0

    // Lightweight in-memory caches for fast initial render.
    @Published var cachedGuideTours: [String: [Tour]] = [:]
    @Published var cachedHostExperiences: [String: [Experience]] = [:]
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        session.$currentUser
            .sink { [weak self] user in
                guard let self else { return }
                if let code = user?.preferredLanguageCode, !code.isEmpty {
                    self.settings.setLanguage(code)
                }

                // Start/stop chat unread tracking as the logged-in user changes.
                if let user {
                    ChatUnreadService.shared.start(role: user.role, uid: user.id)
                } else {
                    ChatUnreadService.shared.stop()
                }
            }
            .store(in: &cancellables)

        session.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send()
        }.store(in: &cancellables)

        // Forward settings changes (e.g. language switch) to refresh all views.
        settings.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }
}
