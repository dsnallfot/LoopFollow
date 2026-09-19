import UIKit
import Charts

extension GlucoseStatsViewController {
    /// Counts "unicorn" readings (≈ 5.5 mmol/L) per day, deduped to match GlucoseView.
    func unicornCountsByDayFromSGVJSON(_ sgvs: [SGVJSON]) -> [Date: Int] {
        let cal = Calendar.current

        // Per dag: set av tidsbuckets (4-min, samma som allValuesDayEntries)
        var bucketsByDay: [Date: Set<Int>] = [:]

        for e in sgvs {
            // SGVJSON.sgv är mg/dL → konvertera till mmol/L
            let mmol = Double(e.sgv) / 18.0182

            // Samma tolerans som i GlucoseView (🦄-etiketten)
            guard abs(mmol - 5.5) < 0.02 else { continue }

            let date = Date(timeIntervalSince1970: e.date)
            let dayStart = cal.startOfDay(for: date)

            // Dedupera på 4-minutersbuckets ungefär som dedupeToBuckets(..., bucketSeconds: 240)
            let bucket = Int(floor(date.timeIntervalSince1970 / 240.0))

            var set = bucketsByDay[dayStart] ?? []
            set.insert(bucket)
            bucketsByDay[dayStart] = set
        }

        var counts: [Date: Int] = [:]
        counts.reserveCapacity(bucketsByDay.count)
        for (day, set) in bucketsByDay {
            counts[day] = set.count
        }
        return counts
    }
    /// Counts unique readings per day by bucketing timestamps.
    func countsByDayFromSGVJSON(_ sgvs: [SGVJSON], bucketSeconds: TimeInterval) -> [Date: Int] {
        let cal = Calendar.current
        var bucketsByDay: [Date: Set<Int>] = [:]

        for e in sgvs {
            let date = Date(timeIntervalSince1970: e.date)
            let dayStart = cal.startOfDay(for: date)
            let bucket = Int(floor(date.timeIntervalSince1970 / bucketSeconds))
            bucketsByDay[dayStart, default: []].insert(bucket)
        }

        var counts: [Date: Int] = [:]
        counts.reserveCapacity(bucketsByDay.count)
        for (day, set) in bucketsByDay {
            counts[day] = set.count
        }
        return counts
    }
}
