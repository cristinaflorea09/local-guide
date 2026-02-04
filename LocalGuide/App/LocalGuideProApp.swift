import SwiftUI
import FirebaseCore
import FirebaseAppCheck
#if canImport(GoogleMaps)
import GoogleMaps
#endif

final class AppCheckFactory: NSObject, AppCheckProviderFactory {
    override init() { super.init() }
    func createProvider(with app: FirebaseApp) -> AppCheckProvider? {
        #if targetEnvironment(simulator)
        return AppCheckDebugProvider(app: app)
        #else
        if #available(iOS 14.0, *) {
            return AppAttestProvider(app: app)
        } else {
            return DeviceCheckProvider(app: app)
        }
        #endif
    }
}

@main
struct LocalGuideProApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState()
    @StateObject private var chatUnread = ChatUnreadService.shared

    init() {
        #if DEBUG
        AppCheck.setAppCheckProviderFactory(AppCheckDebugProviderFactory())
        #else
        if #available(iOS 14.0, *) {
            AppCheck.setAppCheckProviderFactory(AppAttestProviderFactory())
        } else {
            AppCheck.setAppCheckProviderFactory(DeviceCheckProviderFactory())
        }
        #endif
        if FirebaseApp.app() == nil {
            if let options = AppEnvironment.firebaseOptions {
                FirebaseApp.configure(options: options)
            } else {
                FirebaseApp.configure()
            }
        }
#if canImport(GoogleMaps)
// TODO: Put your key in AppConfig.googleMapsAPIKey
if !AppConfig.googleMapsAPIKey.isEmpty {
    GMSServices.provideAPIKey(AppConfig.googleMapsAPIKey)
}
#endif
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .environmentObject(chatUnread)
        }
    }
}
