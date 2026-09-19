import UIKit
import Charts

extension LowTreatmentsStatsViewController {
    // MARK: - Stats helpers

    var totalDays: Int { selectedDays.count }
    var daysWithTreatments: Int { selectedCounts.filter { $0 > 0 }.count }
    var totalTreatments: Int { selectedTreatmentDates.count }
    private var totalGrams: Double { selectedTreatmentGrams.reduce(0, +) }

    // Fördelning på antal dextro per behandling, baserat på gram kh
    // 1 dextro ≈ 0–3 g, 2 dextro ≈ 4–6 g, 3+ dextro > 6 g
    var oneDextroCount: Int {
        selectedTreatmentGrams.filter { $0 >= 0 && $0 <= 3 }.count
    }

    var twoDextroCount: Int {
        selectedTreatmentGrams.filter { $0 > 3 && $0 <= 6 }.count
    }

    var threePlusDextroCount: Int {
        selectedTreatmentGrams.filter { $0 > 6 }.count
    }

    // Nattetid definieras som 22:00–06:00
    var nightTreatmentCount: Int {
        guard !selectedTreatmentDates.isEmpty else { return 0 }
        let cal = Calendar.current
        var count = 0
        for date in selectedTreatmentDates {
            let hour = cal.component(.hour, from: date)
            if hour >= 22 || hour < 6 {
                count += 1
            }
        }
        return count
    }

var dextroWithFingerstickCount: Int {
    selectedTreatmentHasBGCheck.filter { $0 }.count
}

    func longestStreakWithoutTreatmentHours() -> Int {
        guard selectedTreatmentDates.count >= 2 else {
            return 0
        }
        let sorted = selectedTreatmentDates.sorted()
        var maxGap: TimeInterval = 0
        for i in 1..<sorted.count {
            let gap = sorted[i].timeIntervalSince(sorted[i - 1])
            if gap > maxGap { maxGap = gap }
        }
        let hours = Int(maxGap / 3600)
        return hours
    }

    func percentageString(_ numerator: Int, _ denominator: Int) -> String {
        guard denominator > 0 else { return "0 %"
        }
        let p = Double(numerator) * 100.0 / Double(denominator)
        return String(format: "%.0f% %", p)
    }
}
