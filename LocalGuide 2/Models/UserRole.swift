import Foundation

enum UserRole: String, Codable {
    case traveler   // formerly user
    case guide
    case host       // cultural experiences seller (not traveler)
    case admin
}
