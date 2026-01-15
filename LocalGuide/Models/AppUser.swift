import Foundation

struct AppUser: Codable, Identifiable {
    let id: String
    var email: String?
    var role: UserRole
    var createdAt: Date
    var disabled: Bool

    // Guide onboarding
    var guideProfileCreated: Bool?
    var guideApproved: Bool?

    init(id: String,
         email: String? = nil,
         role: UserRole,
         createdAt: Date = Date(),
         disabled: Bool = false,
         guideProfileCreated: Bool? = nil,
         guideApproved: Bool? = nil) {
        self.id = id
        self.email = email
        self.role = role
        self.createdAt = createdAt
        self.disabled = disabled
        self.guideProfileCreated = guideProfileCreated
        self.guideApproved = guideApproved
    }
}
