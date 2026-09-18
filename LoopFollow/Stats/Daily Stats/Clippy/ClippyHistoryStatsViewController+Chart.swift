import SwiftUI
import UIKit
import Charts

@available(iOS 26.0, *)
extension ClippyHistoryStatsViewController {
    func setupChartHeader() {
        let container = UIView()
        container.frame = CGRect(x: 0, y: 0, width: tableView.bounds.width, height: 340)
        container.backgroundColor = .clear

        container.addSubview(periodControl)
        container.addSubview(timeChartView)

        periodControl.translatesAutoresizingMaskIntoConstraints = false
        timeChartView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            periodControl.topAnchor.constraint(equalTo: container.topAnchor, constant: 8),
            periodControl.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            periodControl.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),

            timeChartView.topAnchor.constraint(equalTo: periodControl.bottomAnchor, constant: 12),
            timeChartView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            timeChartView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
            timeChartView.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: 0),
        ])

        tableView.tableHeaderView = container
    }

    func loadChartData() {
        guard !selectedDays.isEmpty else {
            timeChartView.data = nil
            timeChartView.setNeedsDisplay()
            return
        }

        let yellowColor = UIColor.systemYellow.withAlphaComponent(0.95)
        let redColor = UIColor.systemRed.withAlphaComponent(0.95)

        let reachedSet = ScatterChartDataSet(entries: reachedEntries, label: "Mål nåddes")
        reachedSet.setColor(yellowColor)
        reachedSet.setScatterShape(.circle)
        reachedSet.scatterShapeSize = 8
        reachedSet.drawValuesEnabled = false

        let missedSet = ScatterChartDataSet(entries: missedEntries, label: "Mål nåddes ej")
        missedSet.setColor(redColor)
        missedSet.setScatterShape(.circle)
        missedSet.scatterShapeSize = 8
        missedSet.drawValuesEnabled = false

        timeChartView.data = ScatterChartData(dataSets: [reachedSet, missedSet])
        timeChartView.autoScaleMinMaxEnabled = false
        timeChartView.notifyDataSetChanged()

        timeChartView.drawGridBackgroundEnabled = true
        timeChartView.gridBackgroundColor = NSUIColor.systemBackground.withAlphaComponent(0.5)

        let legend = timeChartView.legend
        legend.enabled = true
        legend.drawInside = false
        legend.orientation = .horizontal
        legend.verticalAlignment = .bottom
        legend.horizontalAlignment = .center
        legend.xEntrySpace = 12
        legend.formToTextSpace = 6
        legend.yOffset = 6

        let reachedLegend = LegendEntry(label: "Mål nåddes")
        reachedLegend.form = .circle
        reachedLegend.formSize = 8
        reachedLegend.formColor = yellowColor

        let missedLegend = LegendEntry(label: "Mål nåddes ej")
        missedLegend.form = .circle
        missedLegend.formSize = 8
        missedLegend.formColor = redColor

        legend.setCustom(entries: [reachedLegend, missedLegend])
        timeChartView.extraBottomOffset = 8

        let df = DateFormatter()
        df.locale = Locale(identifier: "sv_SE")
        df.dateFormat = "dd/MM"
        let labels = selectedDays.map { df.string(from: $0) }

        let xAxis = timeChartView.xAxis
        xAxis.labelPosition = .bottom
        xAxis.granularity = 1
        xAxis.granularityEnabled = true
        xAxis.valueFormatter = IndexAxisValueFormatter(values: labels)
        xAxis.setLabelCount(min(6, labels.count), force: false)

        let yAxis = timeChartView.leftAxis
        yAxis.axisMinimum = 0
        yAxis.axisMaximum = 24
        yAxis.granularity = 1
        yAxis.granularityEnabled = true
        yAxis.setLabelCount(25, force: false)
        yAxis.valueFormatter = DefaultAxisValueFormatter { value, _ in
            let v = Int(value.rounded())
            guard [0, 6, 12, 18, 24].contains(v) else { return "" }
            return String(format: "%02d:00", v)
        }

        yAxis.removeAllLimitLines()
        let majorLineColor = UIColor.lightGray.withAlphaComponent(0.65)
        for hour in [0.0, 6.0, 12.0, 18.0, 24.0] {
            let ll = ChartLimitLine(limit: hour)
            ll.lineWidth = 0.8
            ll.lineColor = majorLineColor
            ll.lineDashLengths = []
            ll.label = ""
            yAxis.addLimitLine(ll)
        }

        let gridLineColor = UIColor.lightGray.withAlphaComponent(0.5)
        xAxis.gridColor = gridLineColor
        xAxis.gridLineWidth = 0.5
        xAxis.gridLineDashLengths = [2, 2]

        yAxis.gridColor = gridLineColor
        yAxis.gridLineWidth = 0.5
        yAxis.gridLineDashLengths = [2, 2]

        timeChartView.rightAxis.enabled = false
        timeChartView.setNeedsDisplay()
    }
}
