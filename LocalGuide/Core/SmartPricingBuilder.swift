import Foundation

enum SmartPricingBuilder {
    static func build(
        promoPercent: Int,
        promoStart: Date,
        promoEnd: Date,
        lastMinuteHours: Int,
        lastMinutePercent: Int,
        groupMinPeople: Int,
        groupPercent: Int
    ) -> SmartPricing? {
        var sp = SmartPricing()
        let fmt = ISO8601DateFormatter()

        if promoPercent > 0 {
            let campaign = PromoCampaign(
                id: UUID().uuidString,
                name: "Promo",
                startISO: fmt.string(from: promoStart),
                endISO: fmt.string(from: promoEnd),
                percentOff: promoPercent,
                code: nil
            )
            sp.promoCampaigns = [campaign]
        }

        if lastMinutePercent > 0 {
            sp.lastMinute = LastMinuteDiscount(hoursBeforeStart: lastMinuteHours, percentOff: lastMinutePercent)
        }

        if groupPercent > 0 {
            sp.groupTiers = [GroupTier(id: UUID().uuidString, minPeople: groupMinPeople, percentOff: groupPercent)]
        }

        // If nothing configured, return nil
        let hasAny = (sp.promoCampaigns?.isEmpty == false) || (sp.lastMinute != nil) || (sp.groupTiers?.isEmpty == false)
        return hasAny ? sp : nil
    }
}
