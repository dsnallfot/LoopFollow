import UIKit
import Charts

extension BGCheckStatsViewController {
    func defaultPeriod() -> PeriodOption {
        let count = allDays.count
        // Defaulta till 14 dagar om möjligt,
        // annars falla tillbaka till kortare perioder vid behov.
        if count >= 14 { return .d14 }
        if count >= 7  { return .d7 }
        return .d7
    }

    func applyPeriod(_ period: PeriodOption) {
        selectedPeriod = period
        let total = allDays.count
        guard total > 0 else {
            selectedDays = []
            selectedCounts = []
            selectedDextroCounts = []
            selectedBGCheckDates = []
            chartView.data = nil
            timeChartView.data = nil
            tableView.reloadData()
            return
        }

        let n = min(period.days, total)
        let startIndex = max(0, total - n)
        selectedDays = Array(allDays[startIndex..<total])
        selectedCounts = Array(allCounts[startIndex..<total])
        selectedDextroCounts = Array(allDextroCounts[startIndex..<total])

        // Compute date range for the selected days and filter BGCheck timestamps into it.
        if let firstDay = selectedDays.first, let lastDay = selectedDays.last {
            let cal = Calendar.current
            let start = cal.startOfDay(for: firstDay)
            let end = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: lastDay)) ?? Date.distantFuture
            selectedBGCheckDates = allBGCheckDates
                .filter { $0 >= start && $0 < end }
                .sorted()
            selectedBGCheckDextroDates = allBGCheckDextroDates
                .filter { $0 >= start && $0 < end }
                .sorted()
            selectedBGCheckEntries = allBGCheckEntries
                .filter { $0.date >= start && $0.date < end }
                .sorted { $0.date < $1.date }
        } else {
            selectedBGCheckDates = []
            selectedBGCheckDextroDates = []
            selectedBGCheckEntries = []
        }

        loadChartData()
        tableView.reloadData()
    }

    @objc func periodChanged(_ sender: UISegmentedControl) {
        let index = sender.selectedSegmentIndex
        guard index >= 0 && index < PeriodOption.allCases.count else { return }
        let period = PeriodOption.allCases[index]
        applyPeriod(period)
    }

    @objc func modeChanged(_ sender: UISegmentedControl) {
        let index = sender.selectedSegmentIndex
        guard index >= 0 && index < ChartMode.allCases.count else { return }
        selectedMode = ChartMode.allCases[index]

        let showCount = (selectedMode == .count)
        chartView.isHidden = !showCount
        timeChartView.isHidden = showCount

        loadChartData()
    }
}
