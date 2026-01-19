import Foundation

/// Smart pricing rules + promo campaigns configured per listing.
/// Percent values are 0...100.
struct SmartPricing: Codable {
    /// Weekday discounts where ISO weekday: 1=Mon ... 7=Sun.
    var weekdayDiscountPercentByIsoWeekday: [Int: Int]? = nil

    /// Last-minute discount applied if booking is within `hoursBeforeStart` hours.
    var lastMinute: LastMinuteDiscount? = nil

    /// Seasonal discounts (date ranges).
    var seasonal: [SeasonalDiscount]? = nil

    /// Group pricing tiers, applied based on peopleCount.
    var groupTiers: [GroupTier]? = nil

    /// Promo campaigns configured by the seller (time-boxed percentage discounts).
    var promoCampaigns: [PromoCampaign]? = nil
}

struct PromoCampaign: Codable, Identifiable {
    var id: String
    var name: String
    /// ISO8601 start.
    var startISO: String
    /// ISO8601 end.
    var endISO: String
    var percentOff: Int
    var code: String? = nil
}

struct LastMinuteDiscount: Codable {
    var hoursBeforeStart: Int
    var percentOff: Int
}

struct SeasonalDiscount: Codable, Identifiable {
    var id: String
    var name: String
    var startISO: String
    var endISO: String
    var percentOff: Int
}

struct GroupTier: Codable, Identifiable {
    var id: String
    var minPeople: Int
    var percentOff: Int
}
