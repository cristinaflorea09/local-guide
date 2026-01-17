import Foundation
import Combine

@MainActor
final class AppState: ObservableObject {
    let settings = AppSettings()
    @Published var session = SessionManager()
    @Published var subscription = SubscriptionManager()
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        session.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send()
        }.store(in: &cancellables)
    }
}
