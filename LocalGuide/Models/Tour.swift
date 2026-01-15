import Foundation

struct Tour: Codable, Identifiable {
    let id: String
    var guideId: String
    var title: String
    var description: String
    var city: String
    var coverPhotoURL: String?
    var latitude: Double?
    var longitude: Double?
    var durationMinutes: Int
    var price: Double
    var maxPeople: Int
    var active: Bool
    var createdAt: Date
}
