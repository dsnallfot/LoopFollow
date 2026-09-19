import UIKit
import Charts

extension GlucoseStatsViewController {
    func loadChartData() {
        guard selectedDays.count == selectedCountsAllValues.count,
              selectedDays.count == selectedCountsNSOnly.count,
              !selectedDays.isEmpty
        else {
            chartView.data = nil
            chartView.setNeedsDisplay()
            return
        }

        let n = selectedDays.count
        let expectedPerDay = expectedCountsForSelectedDays()

        var entriesAll: [BarChartDataEntry] = []
        var entriesNS: [BarChartDataEntry] = []
        entriesAll.reserveCapacity(n)
        entriesNS.reserveCapacity(n)

        for i in 0..<n {
            let expected = Double(expectedPerDay[i])
            let pctAll = min(100.0, max(0.0, Double(selectedCountsAllValues[i]) / expected * 100.0))
            let pctNS  = min(100.0, max(0.0, Double(selectedCountsNSOnly[i]) / expected * 100.0))
            entriesAll.append(BarChartDataEntry(x: Double(i), y: pctAll))
            entriesNS.append(BarChartDataEntry(x: Double(i), y: pctNS))
        }

        let dsAll = BarChartDataSet(entries: entriesAll, label: "Alla Dexcomvärden")
        dsAll.setColor(UIColor(
            red: 76.0/255.0,
            green: 179.0/255.0,
            blue: 72.0/255.0,
            alpha: 1.0
        ))

        dsAll.drawValuesEnabled = false
        dsAll.barBorderColor = .black
        dsAll.barBorderWidth = 0.5

        let dsNS = BarChartDataSet(entries: entriesNS, label: "Uppladdningar Trio ⇢ NS")
        dsNS.setColor(UIColor.systemPurple.withAlphaComponent(0.7))
        dsNS.drawValuesEnabled = false
        dsNS.barBorderColor = .black
        dsNS.barBorderWidth = 0.5

        let data = BarChartData(dataSets: [dsAll, dsNS])

        // Grouped bars (two per day)
        let groupSpace = 0.20
        let barSpace = 0.05
        let barWidth = (1.0 - groupSpace) / 2.0 - barSpace
        data.barWidth = barWidth

        // Configure X axis for grouping
        let xAxis = chartView.xAxis
        xAxis.labelPosition = .bottom
        xAxis.granularityEnabled = true
        xAxis.granularity = 1
        xAxis.centerAxisLabelsEnabled = true

        let labels = selectedDays.map { dfAxis.string(from: $0) }
        xAxis.valueFormatter = IndexAxisValueFormatter(values: labels)
        xAxis.setLabelCount(min(6, labels.count), force: false)

        // Y axis: cropped to 70–100 % for better day-to-day resolution
        let yAxis = chartView.leftAxis
        yAxis.axisMinimum = 70
        yAxis.axisMaximum = 100
        yAxis.granularityEnabled = true
        yAxis.granularity = 5
        yAxis.valueFormatter = DefaultAxisValueFormatter { value, _ in
            String(format: "%.0f%%", value)
        }

        chartView.rightAxis.enabled = false

        chartView.data = data

        // Make groups start at x = 0
        chartView.xAxis.axisMinimum = 0
        chartView.xAxis.axisMaximum = Double(n)
        data.groupBars(fromX: 0, groupSpace: groupSpace, barSpace: barSpace)

        chartView.drawGridBackgroundEnabled = true
        chartView.gridBackgroundColor = NSUIColor.systemBackground.withAlphaComponent(0.5)

        // Light grid for readability (same vibe as BGCheck)
        let gridLineColor = UIColor.lightGray.withAlphaComponent(0.5)
        xAxis.gridColor = gridLineColor
        xAxis.gridLineWidth = 0.5
        xAxis.gridLineDashLengths = [2, 2]

        yAxis.gridColor = gridLineColor
        yAxis.gridLineWidth = 0.5
        yAxis.gridLineDashLengths = [2, 2]

        // --- Legend configuration ---
        chartView.legend.enabled = true
        let legend = chartView.legend
        legend.horizontalAlignment = .center
        legend.verticalAlignment = .bottom
        legend.orientation = .horizontal
        legend.drawInside = false
        legend.form = .circle
        legend.formSize = 10
        legend.xEntrySpace = 12
        legend.yOffset = 8
        // Lite extra luft mellan plot-ytan och legend (yOffset påverkar inte alltid layouten)
        chartView.extraBottomOffset = 4

        chartView.notifyDataSetChanged()
        chartView.setNeedsDisplay()
    }
}
