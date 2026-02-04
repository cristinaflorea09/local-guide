import Foundation

/// A custom request from a traveler to a provider (guide/host).
/// Stored in Firestore under `customRequests/{id}` and queried by
/// `requesterId` (traveler user id) and `providerEmail` (guide/host email).
struct CustomRequest: Codable, Identifiable {
    enum Status: String, Codable, CaseIterable {
        case pending
        case accepted
        case declined
        case canceled
        case completed
    }

    let id: String
    var requesterId: String
    var providerEmail: String

    // Optional descriptive fields
    var title: String? = nil
    var message: String? = nil
    var city: String? = nil
    var country: String? = nil
    var preferredDate: Date? = nil
    var budget: Double? = nil

    /// Optional linkage to an in-app listing (tour or experience)
    var listingType: String? = nil // "tour" or "experience"
    var listingId: String? = nil

    var status: Status = .pending

    var createdAt: Date = Date()
    var updatedAt: Date? = nil

    init(
        id: String,
        requesterId: String,
        providerEmail: String,
        title: String? = nil,
        message: String? = nil,
        city: String? = nil,
        country: String? = nil,
        preferredDate: Date? = nil,
        budget: Double? = nil,
        listingType: String? = nil,
        listingId: String? = nil,
        status: Status = .pending,
        createdAt: Date = Date(),
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.requesterId = requesterId
        self.providerEmail = providerEmail
        self.title = title
        self.message = message
        self.city = city
        self.country = country
        self.preferredDate = preferredDate
        self.budget = budget
        self.listingType = listingType
        self.listingId = listingId
        self.status = status
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    // Tolerant decoding so older/partial documents won't crash decoding.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? ""
        requesterId = try c.decodeIfPresent(String.self, forKey: .requesterId) ?? ""
        providerEmail = try c.decodeIfPresent(String.self, forKey: .providerEmail) ?? ""

        title = try c.decodeIfPresent(String.self, forKey: .title)
        message = try c.decodeIfPresent(String.self, forKey: .message)
        city = try c.decodeIfPresent(String.self, forKey: .city)
        country = try c.decodeIfPresent(String.self, forKey: .country)
        preferredDate = try c.decodeIfPresent(Date.self, forKey: .preferredDate)
        budget = try c.decodeIfPresent(Double.self, forKey: .budget)
        listingType = try c.decodeIfPresent(String.self, forKey: .listingType)
        listingId = try c.decodeIfPresent(String.self, forKey: .listingId)

        status = try c.decodeIfPresent(Status.self, forKey: .status) ?? .pending
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        updatedAt = try c.decodeIfPresent(Date.self, forKey: .updatedAt)
    }
}
