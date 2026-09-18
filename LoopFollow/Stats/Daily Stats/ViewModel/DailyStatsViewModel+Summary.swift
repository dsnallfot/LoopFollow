import Foundation

extension DailyStatsViewModel {
    var numberOfDaysMeetingTitrTarget: Int {
        filteredRowsForDisplay.filter { row in
            if let tir = row.tightRangePercent {
                return (tir / 100.0) >= titrTargetThreshold
            } else {
                return false
            }
        }.count
    }
    
    var numberOfDaysMeetingTirTarget: Int {
        filteredRowsForDisplay.filter { row in
            if let tir = row.timeInRangePercent {
                return (tir / 100.0) >= tirTargetThreshold
            } else {
                return false
            }
        }.count
    }

    var numberOfDaysInScope: Int {
        filteredRowsForDisplay.count
    }

    var percentageOfDaysMeetingTarget: Double {
        let scope = numberOfDaysInScope
        guard scope > 0 else { return 0.0 }
        return Double(numberOfDaysMeetingTitrTarget) / Double(scope)
    }

    // MARK: - Aggregated averages for DailyStatsView

    /// Genomsnittliga värden baserat på de dagar som faktiskt är i scope (filteredRowsForDisplay).
    var averageCarbs: Double? {
        let values = filteredRowsForDisplay.compactMap { $0.totalCarbs }
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    var averageTDD: Double? {
        let values = filteredRowsForDisplay.compactMap { $0.insulinTDD }
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    var averageMeanGlucose: Double? {
        let values = filteredRowsForDisplay.compactMap { $0.meanGlucoseMmol }
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    /// Genomsnittlig andel låga värden (%).
    var averageLowPercent: Double? {
        let values = filteredRowsForDisplay.compactMap { $0.lowPercent }
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    /// Genomsnittlig tid i tight målområde (TITR, %).
    var averageTitr: Double? {
        let values = filteredRowsForDisplay.compactMap { $0.tightRangePercent }
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    /// Genomsnittlig tid i målområde (TIR, %).
    var averageTir: Double? {
        let values = filteredRowsForDisplay.compactMap { $0.timeInRangePercent }
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    var averageStdDev: Double? {
        let values = filteredRowsForDisplay.compactMap { $0.stdDevMmol }
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }
/*
    /// Genomsnittlig teoretisk basal (E/dag) från profilen.
    var averageProfileBasal: Double? {
        let values = filteredRowsForDisplay.compactMap { $0.profileBasal }
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }
*/
}
