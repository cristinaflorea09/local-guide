import Foundation
import ObjectiveC.runtime

private var bundleKey: UInt8 = 0

private final class AppLanguageBundle: Bundle, @unchecked Sendable {
    override func localizedString(forKey key: String, value: String?, table tableName: String?) -> String {
        if let bundle = objc_getAssociatedObject(self, &bundleKey) as? Bundle {
            return bundle.localizedString(forKey: key, value: value, table: tableName)
        }
        return super.localizedString(forKey: key, value: value, table: tableName)
    }
}

extension Bundle {
    static func setAppLanguage(_ languageCode: String) {
        object_setClass(Bundle.main, AppLanguageBundle.self)

        let code = languageCode.lowercased().hasPrefix("ro") ? "ro" : "en"
        let path = Bundle.main.path(forResource: code, ofType: "lproj")
        let bundle = path.flatMap { Bundle(path: $0) }
        objc_setAssociatedObject(Bundle.main, &bundleKey, bundle, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }
}
