import SwiftUI

enum AuthRoute: Hashable {
    case landing
    case login
    case rolePicker
    case register(UserRole)
}

@MainActor
final class AuthRouter: ObservableObject {
    @Published var path: [AuthRoute] = []
    func goToLogin() { path = [.login] }
    func goToLanding() { path = [] }
    func goToRegister(_ role: UserRole) { path = [.rolePicker, .register(role)] }
}

struct AuthFlowView: View {
    @StateObject var router = AuthRouter()
    let appState: AppState
    var startAt: AuthRoute? = nil

    var body: some View {
        NavigationStack(path: $router.path) {
            AuthLandingView()
                .environmentObject(router)
                .navigationDestination(for: AuthRoute.self) { route in
                    switch route {
                    case .landing:
                        AuthLandingView().environmentObject(router)
                    case .login:
                        LoginView().environmentObject(router)
                    case .rolePicker:
                        RolePickerView().environmentObject(router)
                    case .register(let role):
                        RegisterView(appState: appState, role: role).environmentObject(router)
                    }
                }
        }
        .onAppear {
            if let startAt, router.path.isEmpty {
                router.path = [startAt]
            }
        }
    }
}
