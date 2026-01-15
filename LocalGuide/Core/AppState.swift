import Foundation

@MainActor
final class AppState: ObservableObject {
    @Published var session = SessionManager()
    @Published var subscription = SubscriptionManager()
}
