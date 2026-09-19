import UIKit
import Charts

extension GlucoseStatsViewController {
    // MARK: - Unicorn badge

    /// Updates the 🦄 badge in the top-left corner based on the current period's total unicorn count.
    private func updateUnicornBadge(for count: Int) {
        if count > 0 {
            let title = "🦄 \(count)"
            let item = UIBarButtonItem(title: title, style: .plain, target: nil, action: nil)
            item.isEnabled = false
            navigationItem.leftBarButtonItem = item
        } else {
            navigationItem.leftBarButtonItem = nil
        }
    }

    // MARK: - Period selection

    func applyPeriod(_ period: PeriodOption) {
        selectedPeriod = period
        let total = allDays.count
        guard total > 0 else {
            selectedDays = []
            selectedCountsAllValues = []
            selectedCountsNSOnly = []
            chartView.data = nil
            tableView.reloadData()
            return
        }

        let n = min(period.days, total)
        let startIndex = max(0, total - n)

        selectedDays = Array(allDays[startIndex..<total])
        selectedCountsAllValues = Array(allCountsAllValues[startIndex..<total])
        selectedCountsNSOnly = Array(allCountsNSOnly[startIndex..<total])

        // Filter sensor errors to the selected period
        let cal = Calendar.current
        let periodStart = cal.startOfDay(for: selectedDays.first ?? Date())
        let periodEnd = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: selectedDays.last ?? Date())) ?? Date()
        self.selectedSensorErrorOutages = allSensorErrorOutages.filter { $0.noteDate >= periodStart && $0.noteDate < periodEnd }

        // Unicorn count for the selected period (sum of per-day unicorns over selectedDays)
        let unicornCount = selectedDays.reduce(0) { $0 + (unicornsByDay[$1] ?? 0) }
        updateUnicornBadge(for: unicornCount)

        if selectedChartMode == .sensorErrors {
            updateSensorErrorChart()
        }

        loadChartData()
        chartView.isHidden = (selectedChartMode == .sensorErrors)
        sensorErrorChartView.isHidden = (selectedChartMode != .sensorErrors)
        tableView.reloadData()
    }

    @objc func periodChanged(_ sender: UISegmentedControl) {
        let index = sender.selectedSegmentIndex
        guard index >= 0 && index < PeriodOption.allCases.count else { return }
        applyPeriod(PeriodOption.allCases[index])
    }

    @objc func chartModeChanged(_ sender: UISegmentedControl) {
        let idx = sender.selectedSegmentIndex
        selectedChartMode = ChartMode(rawValue: idx) ?? .glucoseValues

        chartView.isHidden = (selectedChartMode == .sensorErrors)
        sensorErrorChartView.isHidden = (selectedChartMode != .sensorErrors)

        if selectedChartMode == .sensorErrors {
            updateSensorErrorChart()
        }
    }
}
