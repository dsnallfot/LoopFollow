import UIKit
import Charts

extension GlucoseStatsViewController {
    // MARK: - Expected counts helper

    private func expectedCount(for day: Date) -> Int {
        let cal = Calendar.current
        let start = cal.startOfDay(for: day)
        guard let end = cal.date(byAdding: .day, value: 1, to: start) else { return 288 }

        // For today, only count expected slots up to now (clamped within the day).
        let upper: Date
        if cal.isDateInToday(day) {
            upper = min(Date(), end)
        } else {
            upper = end
        }

        let seconds = max(0, upper.timeIntervalSince(start))
        return max(1, Int(floor(seconds / 300.0)))
    }

    func expectedCountsForSelectedDays() -> [Int] {
        selectedDays.map { expectedCount(for: $0) }
    }

    /// Counts extreme glucose values within the selected period.
    /// Low  <= 2.2 mmol/L (40 mg/dL)
    /// High >= 22.2 mmol/L (400 mg/dL)
    func countExtremeValuesForSelectedPeriod() -> (low: Int, high: Int) {
        guard !selectedDays.isEmpty else { return (0, 0) }

        let cal = Calendar.current
        let periodStart = cal.startOfDay(for: selectedDays.first!)
        let periodEnd = cal.date(
            byAdding: .day,
            value: 1,
            to: cal.startOfDay(for: selectedDays.last!)
        ) ?? Date()

        var low = 0
        var high = 0

        for e in allSGVJSON {
            let d = Date(timeIntervalSince1970: e.date)
            guard d >= periodStart && d < periodEnd else { continue }

            // SGVJSON.sgv is mg/dL
            if e.sgv <= 40 {
                low += 1
            } else if e.sgv >= 400 {
                high += 1
            }
        }
        return (low, high)
    }

    func percentString(_ value: Double) -> String {
        String(format: "%.0f %%", value)
    }

    func countString(_ value: Double) -> String {
        // keep one decimal if needed
        if abs(value.rounded() - value) < 0.001 {
            return String(format: "%.0f", value)
        }
        return String(format: "%.1f", value)
    }

    func avg(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }
}
