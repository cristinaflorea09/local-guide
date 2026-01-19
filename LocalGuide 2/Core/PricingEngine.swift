import Foundation

struct PricingBreakdown {
    let basePerPerson: Double
    let peopleCount: Int
    let appliedPercentOff: Int
    let appliedLabel: String?
    let total: Double
}

enum PricingEngine {
    /// Computes total price with optional smart pricing.
    /// Applies the single best percent discount among: promo, weekday, last-minute, seasonal, group.
    static func computeTotal(basePerPerson: Double, start: Date, peopleCount: Int, smartPricing: SmartPricing?) -> PricingBreakdown {
        let baseTotal = max(0, basePerPerson) * Double(max(1, peopleCount))
        guard let sp = smartPricing else {
            return PricingBreakdown(basePerPerson: basePerPerson, peopleCount: peopleCount, appliedPercentOff: 0, appliedLabel: nil, total: baseTotal)
        }

        var candidates: [(percent: Int, label: String)] = []

        // Promo campaigns
        if let promos = sp.promoCampaigns {
            for p in promos {
                if isActive(startISO: p.startISO, endISO: p.endISO, at: Date()) {
                    candidates.append((clampPercent(p.percentOff), p.name.isEmpty ? "Promo" : p.name))
                }
            }
        }

        // Weekday discounts
        if let map = sp.weekdayDiscountPercentByIsoWeekday {
            let wd = isoWeekday(for: start)
            if let pct = map[wd], pct > 0 {
                candidates.append((clampPercent(pct), "Weekday"))
            }
        }

        // Last-minute
        if let lm = sp.lastMinute {
            let hours = hoursBetween(Date(), start)
            if hours >= 0 && hours <= lm.hoursBeforeStart {
                candidates.append((clampPercent(lm.percentOff), "Last minute"))
            }
        }

        // Seasonal
        if let seasons = sp.seasonal {
            for s in seasons {
                if isActive(startISO: s.startISO, endISO: s.endISO, at: start) {
                    candidates.append((clampPercent(s.percentOff), s.name.isEmpty ? "Seasonal" : s.name))
                }
            }
        }

        // Group
        if let tiers = sp.groupTiers {
            let applicable = tiers.filter { peopleCount >= $0.minPeople }
            if let best = applicable.max(by: { $0.percentOff < $1.percentOff }) {
                candidates.append((clampPercent(best.percentOff), "Group"))
            }
        }

        let best = candidates.max(by: { $0.percent < $1.percent })
        let pct = best?.percent ?? 0
        let total = baseTotal * (1.0 - (Double(pct) / 100.0))
        return PricingBreakdown(basePerPerson: basePerPerson, peopleCount: peopleCount, appliedPercentOff: pct, appliedLabel: best?.label, total: total)
    }

    private static func clampPercent(_ v: Int) -> Int { max(0, min(100, v)) }

    private static func isoWeekday(for date: Date) -> Int {
        // 1 = Monday ... 7 = Sunday
        var cal = Calendar(identifier: .iso8601)
        cal.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return cal.component(.weekday, from: date) == 1 ? 7 : (cal.component(.weekday, from: date) - 1)
    }

    private static func hoursBetween(_ a: Date, _ b: Date) -> Int {
        Int((b.timeIntervalSince(a) / 3600.0).rounded(.down))
    }

    private static func isActive(startISO: String, endISO: String, at: Date) -> Bool {
        let fmt = ISO8601DateFormatter()
        guard let s = fmt.date(from: startISO), let e = fmt.date(from: endISO) else { return false }
        return at >= s && at <= e
    }
}
