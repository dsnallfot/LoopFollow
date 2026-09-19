import UIKit
import Charts

extension GlucoseStatsViewController {
    func updateSensorErrorChart() {
        guard !selectedSensorErrorOutages.isEmpty else {
            sensorErrorChartView.data = nil
            sensorErrorChartView.setNeedsDisplay()
            return
        }

        let cal = Calendar.current

        // Index per dag för x-position (matchar BGCheck time-scatter)
        let periodDays = selectedDays
        var indexByDay: [Date: Int] = [:]
        indexByDay.reserveCapacity(periodDays.count)
        for (idx, d) in periodDays.enumerated() {
            indexByDay[cal.startOfDay(for: d)] = idx
        }

        // X-axis labels = datum (kompakt format) för varje index
        let df = DateFormatter()
        df.locale = Locale(identifier: "sv_SE")
        df.dateFormat = "dd/MM"
        let labels = periodDays.map { df.string(from: $0) }

        // Hjälpfunktion: timestamp -> timmar på dygnet (0–24)
        func hourOfDay(for date: Date) -> Double {
            let comps = cal.dateComponents([.hour, .minute, .second], from: date)
            let h = Double(comps.hour ?? 0)
            let m = Double(comps.minute ?? 0)
            let s = Double(comps.second ?? 0)
            return h + (m / 60.0) + (s / 3600.0)
        }

        // Points: flera sensorfel kan landa på samma dagIndex (samma x)
        var entries: [ChartDataEntry] = []
        entries.reserveCapacity(selectedSensorErrorOutages.count)

        for o in selectedSensorErrorOutages {
            let dayStart = cal.startOfDay(for: o.noteDate)
            guard let dayIndex = indexByDay[dayStart] else { continue }
            entries.append(ChartDataEntry(x: Double(dayIndex), y: hourOfDay(for: o.noteDate)))
        }

        // Viktigt: sortera entries för att undvika Charts-bug där punkter kan försvinna vid zoom/scroll
        entries.sort {
            if $0.x == $1.x { return $0.y < $1.y }
            return $0.x < $1.x
        }

        let ds = ScatterChartDataSet(entries: entries, label: "Sensorfel")
        ds.drawValuesEnabled = false
        ds.setScatterShape(.circle)
        ds.scatterShapeSize = 7
        ds.setColor(.black)
        ds.scatterShapeHoleRadius = 3
        ds.scatterShapeHoleColor = .systemRed

        let data = ScatterChartData(dataSet: ds)
        sensorErrorChartView.data = data

        // X-axis (match BGCheck time-scatter)
        let xAxis = sensorErrorChartView.xAxis
        xAxis.labelPosition = .bottom
        xAxis.granularity = 1
        xAxis.granularityEnabled = true
        xAxis.valueFormatter = IndexAxisValueFormatter(values: labels)
        xAxis.setLabelCount(min(6, labels.count), force: false)

        // Ensure stable visible range during zoom
        xAxis.axisMinimum = -0.5
        xAxis.axisMaximum = Double(max(0, labels.count - 1)) + 0.5

        // Y-axel = timmar 0–24 (dashad grid) + solida huvudlinjer 00/06/12/18/24
        let yAxis = sensorErrorChartView.leftAxis
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

        sensorErrorChartView.rightAxis.enabled = false

        // Light grid
        let gridLineColor = UIColor.lightGray.withAlphaComponent(0.5)
        xAxis.gridColor = gridLineColor
        xAxis.gridLineWidth = 0.5
        xAxis.gridLineDashLengths = [2, 2]

        yAxis.gridColor = gridLineColor
        yAxis.gridLineWidth = 0.5
        yAxis.gridLineDashLengths = [2, 2]

        sensorErrorChartView.drawGridBackgroundEnabled = true
        sensorErrorChartView.gridBackgroundColor = NSUIColor.systemBackground.withAlphaComponent(0.5)

        sensorErrorChartView.notifyDataSetChanged()
        sensorErrorChartView.setNeedsDisplay()
    }
}
