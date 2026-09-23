import Foundation

struct LoopEntry {
    let date: Date
    let note: String
}


extension LoopEntry {
    /// Entries are newest first. Prefer the latest loop error on the chosen day;
    /// otherwise use the closest calendar day, preferring the newer one on a tie.
    static func nearestIndex(to date: Date, in entries: [LoopEntry], calendar: Calendar = .current) -> Int? {
        let selectedDay = calendar.startOfDay(for: date)
        return entries.indices.min { lhs, rhs in
            func distance(_ index: Int) -> Int {
                let day = calendar.startOfDay(for: entries[index].date)
                return abs(calendar.dateComponents([.day], from: selectedDay, to: day).day ?? 0)
            }
            return distance(lhs) < distance(rhs)
        }
    }
}

/// Statistics are bounded by the selected calendar days and the data snapshot time.
struct LoopStatistics {
    let counts: [Int]
    let dates: [Date]
    let start: Date
    let end: Date
    var calendar: Calendar = .current

    /// Completed days contribute 288 slots; the current day contributes elapsed five-minute slots.
    var expectedLoops: Int {
        counts.indices.reduce(0) { total, offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: start),
                  let nextDay = calendar.date(byAdding: .day, value: 1, to: day),
                  end > day else { return total }
            return total + (end >= nextDay ? 288 : Int(end.timeIntervalSince(day) / 300))
        }
    }
    var successfulLoopPercentage: Double? {
        guard expectedLoops > 0 else { return nil }
        return max(0, Double(expectedLoops - total) * 100 / Double(expectedLoops))
    }

    var total: Int { counts.reduce(0, +) }
    var daysWithErrors: Int { counts.filter { $0 > 0 }.count }
    var averagePerDay: Double { counts.isEmpty ? 0 : Double(total) / Double(counts.count) }
    var averagePerErrorDay: Double? {
        daysWithErrors == 0 ? nil : Double(total) / Double(daysWithErrors)
    }
    var percentageOfDaysWithErrors: Double {
        counts.isEmpty ? 0 : Double(daysWithErrors) * 100 / Double(counts.count)
    }
    var maximumPerDay: Int { counts.max() ?? 0 }
    var longestErrorFreeHours: Int {
        guard end > start else { return 0 }
        let boundaries = [start] + dates.filter { $0 >= start && $0 <= end }.sorted() + [end]
        let longest = zip(boundaries, boundaries.dropFirst())
            .map { $1.timeIntervalSince($0) }.max() ?? 0
        return Int(longest / 3600)
    }
}
