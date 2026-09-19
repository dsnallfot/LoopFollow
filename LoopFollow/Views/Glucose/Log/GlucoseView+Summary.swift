import UIKit
import Charts

extension GlucoseView {
    /// Expected number of 5-min glucose slots for a given calendar day.
    /// Handles DST transitions (23h/25h days) by using the actual local day length.
    private func expectedSlots(for day: Date, upTo now: Date? = nil) -> Int {
        let cal = Calendar.current
        let start = cal.startOfDay(for: day)
        guard let end = cal.date(byAdding: .day, value: 1, to: start) else { return 288 }

        // If an upper bound is provided (e.g. "today"), clamp within the day.
        let upper = min(now ?? end, end)
        let seconds = max(0, upper.timeIntervalSince(start))

        // 5-min buckets
        return max(1, Int(floor(seconds / 300.0)))
    }

    func updateStatsLabel() {
        if dataMode == .sensorErrors {
            statsLabel.text = "Sensorfel: \(sensorErrorRows.count) st"
            return
        }
        let cal = Calendar.current
        let start = cal.startOfDay(for: selectedDate)
        guard let end = cal.date(byAdding: .day, value: 1, to: start) else {
            statsLabel.text = "CGM-värden: –"
            return
        }

        let now = Date()
        let isToday = cal.isDate(selectedDate, inSameDayAs: now)

        let actualCount = bgEntries.filter { $0.date >= start && $0.date < end }.count

        let expectedCount: Int
        if isToday {
            expectedCount = expectedSlots(for: selectedDate, upTo: now)
        } else {
            expectedCount = expectedSlots(for: selectedDate)
        }
        // Hantera lägen där inga värden missats ännu, och de sekunder mellan att ett cgm-värde kommit in och 5 min indelningen av dygnets timmar ger en diff (ex cgm värden kommer minut:sekund 02:30, 07:30, 12:30 osv. expectedCOunt utgår från 05:00, 10:00, 15:00. Det gör at cgm % blir högre än 100% mellan minut:sekund 02:30-05:00, 07:30-10:00, 12:30-15:00 osv utan denna expectedCOuntAdjusted-fix
        var expectedCountAdjusted: Int
        if actualCount > expectedCount {
            expectedCountAdjusted = actualCount
        } else {
            expectedCountAdjusted = expectedCount
        }

        // If there is at least one missing reading for the day, make sure we never show 100% coverage
        // during the current 5‑min window while expectedCount has not yet “caught up”.
        let missingCount = dayRowsIncludingMissing.filter { $0.isMissing }.count
        if missingCount > 0 && expectedCountAdjusted == expectedCount {
            expectedCountAdjusted += 1
        }

        let pct = expectedCountAdjusted > 0 ? Int(round(Double(actualCount) / Double(expectedCountAdjusted) * 100.0)) : 0
        var emoji = " 🔴"
        if pct > 95 {
            emoji = " 🟢"
        } else if pct > 90 {
            emoji = " 🟡"
        }
        statsLabel.text = "CGM-värden:  \(actualCount)/\(expectedCount)  \(pct)%" + emoji
    }
}
