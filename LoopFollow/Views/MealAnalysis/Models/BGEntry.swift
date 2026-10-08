import Foundation

/// Glucose data point (mmol/L)
struct BGEntry {
    let date: Date
    let mmol: Double
    var isGapFill: Bool = false
}

/// Retrospective glucose-equivalent insulin difference, not an inferred ISF or a dose recommendation.
enum MealInsulinDifference {
    static func units(start: Date, end: Date, entries: [BGEntry], isf: Double?, now: Date = Date()) -> Double? {
        guard abs(end.timeIntervalSince(start) - 3 * 60 * 60) < 1,
              end <= now,
              let isf, isf.isFinite, isf > 0 else { return nil }

        // Only measured endpoints within one CGM interval; chart gap-fill is not evidence.
        let measured = entries.filter { !$0.isGapFill && $0.mmol.isFinite && $0.mmol > 0 && $0.date <= now }
        func glucose(at date: Date) -> Double? {
            guard let entry = measured.min(by: {
                abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date))
            }), abs(entry.date.timeIntervalSince(date)) <= 5 * 60 else { return nil }
            return entry.mmol
        }
        guard let startBG = glucose(at: start), let endBG = glucose(at: end) else { return nil }
        // (mmol/L) / (mmol/L per E) = E. Positive means a theoretical shortfall.
        let result = (endBG - startBG) / isf
        return result.isFinite ? result : nil
    }

    static func formatted(_ units: Double) -> String {
        // Avoid reporting a signed zero after rounding to two decimals.
        abs(units) < 0.005 ? "0.00 E" : String(format: "%+.2f E", units)
    }

    static func theoreticalCarbRatio(carbs: Double, netInsulin: Double, difference: Double?) -> Double? {
        guard carbs.isFinite, carbs > 0, netInsulin.isFinite,
              let difference, difference.isFinite else { return nil }
        let theoreticalNetInsulin = netInsulin + difference
        guard theoreticalNetInsulin.isFinite, theoreticalNetInsulin > 0 else { return nil }
        let ratio = carbs / theoreticalNetInsulin
        return ratio.isFinite ? ratio : nil
    }
}
