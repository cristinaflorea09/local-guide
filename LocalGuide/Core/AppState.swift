import Foundation
import Combine

@MainActor
final class AppState: ObservableObject {
    var settings = AppSettings()
    @Published var session = SessionManager()
    @Published var subscription = SubscriptionManager()
    
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
