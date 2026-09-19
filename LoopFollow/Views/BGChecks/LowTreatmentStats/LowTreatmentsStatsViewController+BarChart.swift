import UIKit
import Charts

extension LowTreatmentsStatsViewController {
    func loadChartData() {
        // Vi utgår nu bara från vald period + underliggande behandlingar,
        // och räknar om per dag utifrån selectedTimeFilter.
        guard !selectedDays.isEmpty else {
            chartView.data = nil
            chartView.setNeedsDisplay()
            return
        }

        let cal = Calendar.current

        // startOfDay -> dagindex i selectedDays
        var indexByDayStart: [Date: Int] = [:]
        for (idx, day) in selectedDays.enumerated() {
            let dayStart = cal.startOfDay(for: day)
            indexByDayStart[dayStart] = idx
        }

        // Grundarrayen för staplarna (en stapel per dag)
        var yValues = Array(repeating: 0.0, count: selectedDays.count)

        switch selectedMode {
        case .count, .lowAndBg:
            // Räkna antal behandlingar per dag (filtrerat på dag/natt/allTime)
            for date in selectedTreatmentDates {
                guard passesTimeFilter(date) else { continue }
                let dayStart = cal.startOfDay(for: date)
                if let idx = indexByDayStart[dayStart] {
                    yValues[idx] += 1.0
                }
            }

        case .grams:
            // Summera gram per dag (filtrerat på dag/natt/allTime)
            for (date, grams) in zip(selectedTreatmentDates, selectedTreatmentGrams) {
                guard passesTimeFilter(date) else { continue }
                let dayStart = cal.startOfDay(for: date)
                if let idx = indexByDayStart[dayStart] {
                    yValues[idx] += grams
                }
            }
        case .time:
            // Används inte i stapeldiagram
            break
        }

        // Om allt är noll → töm grafen
        if yValues.allSatisfy({ $0 == 0 }) {
            chartView.data = nil
            chartView.setNeedsDisplay()
            return
        }

        // Bygg BarChartDataEntries
        var entries: [BarChartDataEntry] = []
        entries.reserveCapacity(selectedDays.count)

        var maxValue: Double = 0
        for (idx, value) in yValues.enumerated() {
            entries.append(BarChartDataEntry(x: Double(idx), y: value))
            if value > maxValue { maxValue = value }
        }

        let dataSet = BarChartDataSet(entries: entries, label: "")
        dataSet.setColor(.white)
        dataSet.drawValuesEnabled = false
        dataSet.barBorderColor = .black
        dataSet.barBorderWidth = 0.5

        let data = BarChartData(dataSet: dataSet)
        chartView.data = data
        chartView.autoScaleMinMaxEnabled = false
        chartView.notifyDataSetChanged()

        chartView.drawGridBackgroundEnabled = true
        chartView.gridBackgroundColor = NSUIColor.systemBackground.withAlphaComponent(0.5)

        // X-axis labels = datum (kompakt format) för varje dag i selectedDays
        let df = DateFormatter()
        df.locale = Locale(identifier: "sv_SE")
        df.dateFormat = "dd/MM"

        let labels = selectedDays.map { df.string(from: $0) }
        let xAxis = chartView.xAxis
        xAxis.labelPosition = .bottom
        xAxis.granularity = 1
        xAxis.granularityEnabled = true
        xAxis.valueFormatter = IndexAxisValueFormatter(values: labels)
        xAxis.setLabelCount(min(6, labels.count), force: false)

        // Y-axel – dynamiskt max
        let yAxis = chartView.leftAxis
        yAxis.axisMinimum = 0
        let maxY = max(1, maxValue)
        yAxis.axisMaximum = maxY * 1.2
        yAxis.granularity = maxY <= 10 ? 1 : max(1, floor(maxY / 5))
        yAxis.granularityEnabled = true

        // Enhet på vänster y-axel beroende på läge
        switch selectedMode {
        case .count, .lowAndBg:
            yAxis.valueFormatter = DefaultAxisValueFormatter { value, _ in
                String(format: "%.0f ggr", value)
            }
        case .grams:
            yAxis.valueFormatter = DefaultAxisValueFormatter { value, _ in
                String(format: "%.0f g", value)
            }
        case .time:
            // Ingen stapel → ingen formatter behövs
            break
        }

        let gridLineColor = UIColor.lightGray.withAlphaComponent(0.5)
        xAxis.gridColor = gridLineColor
        xAxis.gridLineWidth = 0.5
        xAxis.gridLineDashLengths = [2, 2]

        yAxis.gridColor = gridLineColor
        yAxis.gridLineWidth = 0.5
        yAxis.gridLineDashLengths = [2, 2]

        chartView.rightAxis.enabled = false
        chartView.setNeedsDisplay()
    }

}
