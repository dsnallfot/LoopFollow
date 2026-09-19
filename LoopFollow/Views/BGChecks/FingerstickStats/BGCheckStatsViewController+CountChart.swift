import UIKit
import Charts

extension BGCheckStatsViewController {
    func loadCountChartData() {
        var entries: [BarChartDataEntry] = []
        entries.reserveCapacity(selectedDays.count)

        var maxCount = 0
        for (idx, count) in selectedCounts.enumerated() {
            entries.append(BarChartDataEntry(x: Double(idx), y: Double(count)))
            if count > maxCount { maxCount = count }
        }

        let dataSet = BarChartDataSet(entries: entries, label: "")
        dataSet.setColor(.systemRed)
        dataSet.drawValuesEnabled = false
        dataSet.barBorderColor = .black
        dataSet.barBorderWidth = 0.5

        let data = BarChartData(dataSet: dataSet)
        chartView.data = data
        chartView.autoScaleMinMaxEnabled = false
        chartView.notifyDataSetChanged()
        chartView.drawGridBackgroundEnabled = true
        chartView.gridBackgroundColor = NSUIColor.systemBackground.withAlphaComponent(0.5)

        // X-axis labels = datum (kompakt format) för varje index
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

        // Y-axel – dynamiskt max utifrån högsta antal stick på en dag
        let yAxis = chartView.leftAxis
        yAxis.axisMinimum = 0
        let maxY = max(1, maxCount)
        yAxis.axisMaximum = Double(maxY) * 1.2
        yAxis.granularity = 1
        yAxis.granularityEnabled = true
        yAxis.valueFormatter = DefaultAxisValueFormatter { value, _ in
            String(format: "%.0f ggr", value)
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
