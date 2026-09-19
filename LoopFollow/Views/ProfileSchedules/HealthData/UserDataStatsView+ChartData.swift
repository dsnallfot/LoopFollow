import SwiftUI
import UIKit
import Charts

@available(iOS 16.0, *)
extension UserDataStatsView {
    private var sortedProfiles: [UserProfileEntry] {
        Storage.shared.userProfiles
            .sorted { $0.updatedAt < $1.updatedAt }
    }

    struct ChartConfig {
        let entries: [ChartDataEntry]
        let dates: [Date]
        let style: LineChartStyle
    }

    struct WalshChartConfig {
        let walshEntries: [ChartDataEntry]
        let actualEntries: [ChartDataEntry]
        let dates: [Date]
        let walshLabel: String
        let actualLabel: String
    }

    /// Bygger entries + datum + style för aktuell metric
    var chartConfig: ChartConfig? {
        let valueExtractor: (UserProfileEntry) -> Double?
        let baseColor: NSUIColor
        let circleColorProvider: ((Double) -> NSUIColor)?

        switch selectedMetric {
        case .hba1c:
            valueExtractor = { $0.hbA1c }
            baseColor = .systemGray
            circleColorProvider = { value in
                if value <= 48 {
                    return .systemGreen
                } else if value <= 52 {
                    return .systemOrange
                } else {
                    return .systemRed
                }
            }

        case .weight:
            valueExtractor = { $0.weightKg }
            baseColor = .systemBrown
            circleColorProvider = nil

        case .height:
            valueExtractor = { $0.heightCm }
            baseColor = .cyan
            circleColorProvider = nil

        case .bmi:
            valueExtractor = { entry in
                guard let weight = entry.weightKg,
                      let heightCm = entry.heightCm,
                      heightCm > 0 else { return nil }
                let heightM = heightCm / 100.0
                return weight / (heightM * heightM)
            }
            baseColor = .systemYellow
            circleColorProvider = nil

        case .tdd:
            valueExtractor = { $0.tdd }
            baseColor = .systemBlue
            circleColorProvider = nil
        }

        var entries: [ChartDataEntry] = []
        var dates: [Date] = []

        // 🔹 Första datumet blir x = 0
        guard let firstDate = sortedProfiles.first?.updatedAt else {
            return nil
        }
        let secondsPerDay: Double = 60 * 60 * 24

        for entry in sortedProfiles {
            guard let value = valueExtractor(entry) else { continue }
            let daysSinceStart = entry.updatedAt.timeIntervalSince(firstDate) / secondsPerDay
            entries.append(ChartDataEntry(x: daysSinceStart, y: value))
            dates.append(entry.updatedAt)
        }

        guard !entries.isEmpty else { return nil }

        let style = LineChartStyle(
            lineColor: baseColor,
            showCircles: true,
            circleRadius: 6,
            circleColor: circleColorProvider
        )

        return ChartConfig(entries: entries, dates: dates, style: style)
    }

    /// Bygger entries för jämförelse mellan Walsh-baseline och inställt värde
    var walshChartConfig: WalshChartConfig? {
        let walshExtractor: (UserProfileEntry) -> Double?
        let actualExtractor: (UserProfileEntry) -> Double?
        let walshLabel: String
        let actualLabel: String

        switch selectedComparison {
        case .tdd:
            walshExtractor = { $0.walshTDD }
            actualExtractor = { $0.tdd }
            walshLabel = "Walsh TDD"
            actualLabel = "Aktuell TDD (14d)"
        case .basal:
            walshExtractor = { $0.walshBasal }
            actualExtractor = { $0.actualBasal }
            walshLabel = "Walsh Basal"
            actualLabel = "Aktuell Basal"
        case .isf:
            walshExtractor = { $0.walsh100ISF }
            actualExtractor = { $0.actualAverageISF }
            walshLabel = "Walsh 100-regeln ISF"
            actualLabel = "Aktuell ISF (medel)"
        case .morningCR:
            walshExtractor = { $0.walsh300CR }
            actualExtractor = { $0.actualMorningCR }
            walshLabel = "Walsh 300-regeln CR"
            actualLabel = "Aktuell CR morgon"
        case .dayCR:
            walshExtractor = { $0.walsh500CR }
            actualExtractor = { $0.actualDayCR }
            walshLabel = "Walsh 500-regeln CR"
            actualLabel = "Aktuell CR dag"
        }

        guard let firstDate = sortedProfiles.first?.updatedAt else {
            return nil
        }
        let secondsPerDay: Double = 60 * 60 * 24

        var walshEntries: [ChartDataEntry] = []
        var actualEntries: [ChartDataEntry] = []
        let dates: [Date] = sortedProfiles.map { $0.updatedAt }

        for entry in sortedProfiles {
            let daysSinceStart = entry.updatedAt.timeIntervalSince(firstDate) / secondsPerDay

            if let walshValue = walshExtractor(entry) {
                walshEntries.append(ChartDataEntry(x: daysSinceStart, y: walshValue))
            }
            if let actualValue = actualExtractor(entry) {
                actualEntries.append(ChartDataEntry(x: daysSinceStart, y: actualValue))
            }
        }

        guard !walshEntries.isEmpty || !actualEntries.isEmpty else { return nil }

        return WalshChartConfig(
            walshEntries: walshEntries,
            actualEntries: actualEntries,
            dates: dates,
            walshLabel: walshLabel,
            actualLabel: actualLabel
        )
    }
}
