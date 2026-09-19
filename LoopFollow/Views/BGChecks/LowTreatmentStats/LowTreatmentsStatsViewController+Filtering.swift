import UIKit
import Charts

extension LowTreatmentsStatsViewController {
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
            selectedGramsPerDay = []
            selectedTreatmentDates = []
            selectedTreatmentGrams = []
            chartView.data = nil
            tableView.reloadData()
            return
        }

        let n = min(period.days, total)
        let startIndex = max(0, total - n)
        selectedDays = Array(allDays[startIndex..<total])
        selectedCounts = Array(allCounts[startIndex..<total])
        selectedGramsPerDay = Array(allGramsPerDay[startIndex..<total])

        // Begränsa behandlingar och BG Check till vald period
        if let firstDay = selectedDays.first, let lastDay = selectedDays.last {
            let cal = Calendar.current
            let periodStart = cal.startOfDay(for: firstDay)
            let periodEnd = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: lastDay)) ?? lastDay

            var dates: [Date] = []
            var grams: [Double] = []
            var hasBG: [Bool] = []

            for idx in allTreatmentDates.indices {
                let d = allTreatmentDates[idx]
                if d >= periodStart && d < periodEnd {
                    dates.append(d)
                    grams.append(allTreatmentGrams[idx])
                    hasBG.append(allTreatmentHasBGCheck[idx])
                }
            }
            selectedTreatmentDates = dates
            selectedTreatmentGrams = grams
            selectedTreatmentHasBGCheck = hasBG

            var bgDates: [Date] = []
            var bgMmol: [Double] = []
            for idx in allBGCheckDates.indices {
                let d = allBGCheckDates[idx]
                if d >= periodStart && d < periodEnd {
                    bgDates.append(d)
                    bgMmol.append(allBGCheckMmol[idx])
                }
            }
            selectedBGCheckDates = bgDates
            selectedBGCheckMmol = bgMmol
        } else {
            selectedTreatmentDates = []
            selectedTreatmentGrams = []
            selectedTreatmentHasBGCheck = []
            selectedBGCheckDates = []
            selectedBGCheckMmol = []
        }

        switch selectedMode {
        case .lowAndBg:
            loadLowAndBgChartData()
        case .time:
            loadTreatmentTimeChartData()
        case .count, .grams:
            loadChartData()
        }
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
        guard index >= 0 && index < ModeOption.allCases.count else { return }
        selectedMode = ModeOption.allCases[index]

        let showBars = (selectedMode == .count || selectedMode == .grams)
        chartView.isHidden = !showBars
        scatterChartView.isHidden = (selectedMode != .lowAndBg)
        timeChartView.isHidden = (selectedMode != .time)

        switch selectedMode {
        case .lowAndBg:
            loadLowAndBgChartData()
        case .time:
            loadTreatmentTimeChartData()
        case .count, .grams:
            loadChartData()
        }
    }

    @objc func timeFilterChanged(_ sender: UISegmentedControl) {
        let index = sender.selectedSegmentIndex
        guard index >= 0 && index < TimeFilterOption.allCases.count else { return }
        selectedTimeFilter = TimeFilterOption.allCases[index]

        switch selectedMode {
        case .lowAndBg:
            loadLowAndBgChartData()
        case .time:
            loadTreatmentTimeChartData()
        case .count, .grams:
            loadChartData()
        }
    }

    func passesTimeFilter(_ date: Date) -> Bool {
        switch selectedTimeFilter {
        case .allTime:
            return true
        case .dayTime:
            let hour = Calendar.current.component(.hour, from: date)
            return hour >= 6 && hour < 22   // 06:00–21:59
        case .nightTime:
            let hour = Calendar.current.component(.hour, from: date)
            return hour >= 22 || hour < 6   // 22:00–05:59
        }
    }
}
