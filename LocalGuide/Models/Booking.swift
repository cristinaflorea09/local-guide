import Foundation

/// Firestore-backed booking model.
///
/// Notes on backward compatibility:
/// - Earlier builds used `date` + `totalPrice` (Double).
/// - Current backend uses `startISO`/`endISO` + `totalAmount` (minor units, Int).
///
/// This model decodes **both** formats so old documents don't crash the app.

enum BookingStatus: String, Codable {
    case pendingPayment = "pending_payment"
    case paymentIntentCreated = "payment_intent_created"
    case confirmed = "confirmed"
    case canceled = "canceled"
    case canceledAdmin = "canceled_admin"
    case paymentFailed = "payment_failed"
    case failed = "failed"
}

struct Booking: Codable, Identifiable {
    let id: String
    var tourId: String
    var slotId: String
    var guideEmail: String
    var userId: String

    /// New unified marketplace fields (Tours + Experiences).
    /// Backward compatible: for tours these are often nil and can be derived from tourId/guideId.
    var listingType: String?
    var listingId: String?
    var providerEmail: String?

    /// ISO8601 start/end strings stored by backend.
    var startISO: String?
    var endISO: String?

    /// Legacy (kept for decoding old docs).
    var date: Date?

    var peopleCount: Int

    /// Amount in minor units (cents). Preferred.
    var totalAmount: Int?

    /// Legacy amount in major units.
    var totalPriceLegacy: Double?

    var currency: String
    var status: BookingStatus

    /// Marketplace accounting (minor units) - populated by backend when creating payment intent.
    var commissionPercent: Int?
    var applicationFeeAmount: Int?
    var sellerNetAmount: Int?
    var transferId: String?

    var paymentIntentId: String?
    var createdAt: Date?

    // MARK: Computed
    var startDate: Date {
        if let startISO, let d = ISO8601DateFormatter().date(from: startISO) { return d }
        return date ?? Date.distantPast
    }

    var endDate: Date {
        if let endISO, let d = ISO8601DateFormatter().date(from: endISO) { return d }
        // fallback: 1h duration if we only have date
        return (date ?? Date.distantPast).addingTimeInterval(60 * 60)
    }

    /// Always returns major units for UI (e.g., 12.34).
    var totalPrice: Double {
        if let totalAmount { return Double(totalAmount) / 100.0 }
        return totalPriceLegacy ?? 0
    }

    var isPastEnd: Bool { endDate < Date() }

    enum CodingKeys: String, CodingKey {
        case id
        case tourId
        case slotId
        case guideEmail
        case userId
        case listingType
        case listingId
        case providerEmail
        case startISO
        case endISO
        case date
        case peopleCount
        case totalAmount
        case totalPriceLegacy = "totalPrice"
        case currency
        case status
        case paymentIntentId
        case commissionPercent
        case applicationFeeAmount
        case sellerNetAmount
        case transferId
        case createdAt
    }
}

extension Booking {
    var applicationFeeMajor: Double { Double(applicationFeeAmount ?? 0) / 100.0 }
    var sellerNetMajor: Double { Double(sellerNetAmount ?? 0) / 100.0 }
}

extension Booking {
    var effectiveListingType: String { (listingType ?? "tour").lowercased() }
    var effectiveListingId: String { listingId ?? tourId }
    var effectiveProviderId: String { providerEmail ?? guideEmail }
}
