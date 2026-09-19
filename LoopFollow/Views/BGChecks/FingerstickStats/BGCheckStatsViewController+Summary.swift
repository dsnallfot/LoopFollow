import UIKit
import Charts

extension BGCheckStatsViewController {
    // MARK: - Stats helpers

    var totalDays: Int { selectedDays.count }
    var daysWithSticks: Int { selectedCounts.filter { $0 > 0 }.count }
    var totalSticks: Int { selectedCounts.reduce(0, +) }
    var totalDextroSticks: Int { selectedDextroCounts.reduce(0, +) }
    var maxSticksPerDay: Int { selectedCounts.max() ?? 0 }
    var meanCgm10mDelta: Double? {
        let deltas = selectedBGCheckEntries.compactMap { $0.delta10m }
        guard !deltas.isEmpty else { return nil }
        return deltas.reduce(0, +) / Double(deltas.count)
    }
    func longestStreakWithoutSticks() -> Int {
        var best = 0
        var current = 0
        for c in selectedCounts {
            if c == 0 {
                current += 1
                if current > best { best = current }
            } else {
                current = 0
            }
        }
        return best
    }

    func percentageString(_ numerator: Int, _ denominator: Int) -> String {
        guard denominator > 0 else { return "0 %" }
        let p = Double(numerator) * 100.0 / Double(denominator)
        return String(format: "%.0f% %", p)
    }
}
