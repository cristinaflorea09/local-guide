import Foundation
import os.log

enum Log {
    static let subsystem = Bundle.main.bundleIdentifier ?? "LocalGuide"
    static let general = Logger(subsystem: subsystem, category: "general")
    static let auth = Logger(subsystem: subsystem, category: "auth")
    static let payments = Logger(subsystem: subsystem, category: "payments")
}
