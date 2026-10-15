import UIKit
import Charts

extension BGCheckStatsViewController {
    func loadTimeChartData() {
        timeChartView.noDataText = "Inga fingerstick för perioden"
        timeChartView.extraTopOffset = 0
        let cal = Calendar.current

        // Index per dag för x-position
        var indexByDay: [Date: Int] = [:]
        for (idx, d) in selectedDays.enumerated() {
            indexByDay[cal.startOfDay(for: d)] = idx
        }

        // Hjälpfunktion: timestamp -> timmar på dygnet (0–24)
        func hourOfDay(for date: Date) -> Double {
            let comps = cal.dateComponents([.hour, .minute, .second], from: date)
            let h = Double(comps.hour ?? 0)
            let m = Double(comps.minute ?? 0)
            let s = Double(comps.second ?? 0)
            return h + (m / 60.0) + (s / 3600.0)
        }

        // Dataset 1: Alla fingersticks
        var allPoints: [ChartDataEntry] = []
        allPoints.reserveCapacity(selectedBGCheckDates.count)
        for d in selectedBGCheckDates {
            let dayStart = cal.startOfDay(for: d)
            guard let dayIndex = indexByDay[dayStart] else { continue }
            allPoints.append(ChartDataEntry(x: Double(dayIndex), y: hourOfDay(for: d)))
        }

        // Viktigt: sortera entries för att undvika Charts-bug där punkter kan försvinna vid zoom/scroll
        allPoints.sort {
            if $0.x == $1.x { return $0.y < $1.y }
            return $0.x < $1.x
        }

        // Dataset 2: Fingerstick -> 🍬 (subset)
        var dextroPoints: [ChartDataEntry] = []
        dextroPoints.reserveCapacity(selectedBGCheckDextroDates.count)
        for d in selectedBGCheckDextroDates {
            let dayStart = cal.startOfDay(for: d)
            guard let dayIndex = indexByDay[dayStart] else { continue }
            dextroPoints.append(ChartDataEntry(x: Double(dayIndex), y: hourOfDay(for: d)))
        }

        // Viktigt: sortera entries för att undvika Charts-bug där punkter kan försvinna vid zoom/scroll
        dextroPoints.sort {
            if $0.x == $1.x { return $0.y < $1.y }
            return $0.x < $1.x
        }

        let redColor = UIColor.systemRed
        let purpleColor = UIColor.systemPurple

        let dsAll = ScatterChartDataSet(entries: allPoints, label: "Fingerstick")
        dsAll.setColor(redColor)
        dsAll.setScatterShape(.circle)
        dsAll.scatterShapeSize = 7
        dsAll.drawValuesEnabled = false

        let dsDextro = ScatterChartDataSet(entries: dextroPoints, label: "Fingerstick → 🍬")
        dsDextro.setColor(purpleColor)
        dsDextro.setScatterShape(.circle)
        dsDextro.scatterShapeSize = 7
        dsDextro.drawValuesEnabled = false

        // Lägg dsDextro sist så lila ritas ovanpå röd vid samma koordinat
        let data = ScatterChartData(dataSets: [dsAll, dsDextro])
        timeChartView.data = data
        timeChartView.autoScaleMinMaxEnabled = false
        timeChartView.notifyDataSetChanged()

        configureScatterChartAppearance()

        // X-axis labels = datum (kompakt format) för varje index
        let df = DateFormatter()
        df.locale = Locale(identifier: "sv_SE")
        df.dateFormat = "dd/MM"
        let labels = selectedDays.map { df.string(from: $0) }

        let xAxis = timeChartView.xAxis
        xAxis.resetCustomAxisMin()
        xAxis.resetCustomAxisMax()
        xAxis.labelPosition = .bottom
        xAxis.granularity = 1
        xAxis.granularityEnabled = true
        xAxis.valueFormatter = IndexAxisValueFormatter(values: labels)
        xAxis.setLabelCount(min(6, labels.count), force: false)

        // Y-axel = timmar på dygnet 0–24
        let yAxis = timeChartView.leftAxis
        yAxis.drawGridLinesEnabled = true
        yAxis.drawLimitLinesBehindDataEnabled = false
        yAxis.axisMinimum = 0
        yAxis.axisMaximum = 24

        // Dashad grid för varje timme, men endast labels vid 00/06/12/18/24
        yAxis.granularity = 1
        yAxis.granularityEnabled = true
        yAxis.setLabelCount(25, force: false)
        yAxis.valueFormatter = DefaultAxisValueFormatter { value, _ in
            let v = Int(value.rounded())
            guard [0, 6, 12, 18, 24].contains(v) else { return "" }
            return String(format: "%02d:00", v)
        }

        // Rensa tidigare limit-lines
        yAxis.removeAllLimitLines()

        // Solida huvudlinjer vid 00/06/12/18/24
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
        timeChartView.notifyDataSetChanged()
        timeChartView.setNeedsDisplay()
    }

    private func configureScatterChartAppearance() {
        timeChartView.drawGridBackgroundEnabled = true
        timeChartView.gridBackgroundColor = NSUIColor.systemBackground.withAlphaComponent(0.5)

        // Legend under grafen
        timeChartView.legend.enabled = true
        timeChartView.legend.verticalAlignment = .bottom
        timeChartView.legend.horizontalAlignment = .center
        timeChartView.legend.orientation = .horizontal
        timeChartView.legend.drawInside = false
        timeChartView.legend.yOffset = 6

        let e1 = LegendEntry(label: "Fingerstick")
        e1.form = .circle
        e1.formSize = 8
        e1.formColor = .systemRed

        let e2 = LegendEntry(label: "Fingerstick → 🍬")
        e2.form = .circle
        e2.formSize = 8
        e2.formColor = .systemPurple

        timeChartView.legend.setCustom(entries: [e1, e2])
        timeChartView.extraBottomOffset = 8
    }
}

extension BGCheckStatsViewController {
    func loadDeltaChartData() {
        let calendar = Calendar.current
        let indexByDay = Dictionary(uniqueKeysWithValues: selectedDays.enumerated().map {
            (calendar.startOfDay(for: $0.element), $0.offset)
        })
        var regularPoints: [ChartDataEntry] = []
        var dextroPoints: [ChartDataEntry] = []

        for entry in selectedBGCheckEntries {
            guard let delta = entry.delta10m, delta.isFinite,
                  let day = calendar.dateInterval(of: .day, for: entry.date),
                  let index = indexByDay[day.start] else { continue }
            // Preserve the time within each calendar day, including daylight-saving changes.
            let x = Double(index) + entry.date.timeIntervalSince(day.start) / day.duration
            let point = ChartDataEntry(x: x, y: delta)
            if entry.hasDextroNearby {
                dextroPoints.append(point)
            } else {
                regularPoints.append(point)
            }
        }

        timeChartView.noDataText = "Inga CGM-deltavärden för perioden"
        guard !regularPoints.isEmpty || !dextroPoints.isEmpty else {
            timeChartView.clear()
            return
        }

        let regular = ScatterChartDataSet(entries: regularPoints.sorted { $0.x < $1.x }, label: "Fingerstick")
        let dextro = ScatterChartDataSet(entries: dextroPoints.sorted { $0.x < $1.x }, label: "Fingerstick → 🍬")
        for (dataSet, color) in [(regular, UIColor.systemRed), (dextro, UIColor.systemPurple)] {
            dataSet.setColor(color)
            dataSet.setScatterShape(.circle)
            dataSet.scatterShapeSize = 7
            dataSet.drawValuesEnabled = false
        }
        configureScatterChartAppearance()
        timeChartView.autoScaleMinMaxEnabled = false

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "sv_SE")
        formatter.dateFormat = "dd/MM"
        let labels = selectedDays.map { formatter.string(from: $0) }
        let xAxis = timeChartView.xAxis
        xAxis.axisMinimum = -0.15
        xAxis.axisMaximum = Double(selectedDays.count) + 0.15
        xAxis.labelPosition = .bottom
        xAxis.granularity = 1
        xAxis.granularityEnabled = true
        xAxis.setLabelCount(min(6, max(2, labels.count)), force: false)
        xAxis.valueFormatter = DefaultAxisValueFormatter { value, _ in
            let index = Int(value.rounded())
            guard abs(value - Double(index)) < 0.001, labels.indices.contains(index) else { return "" }
            return labels[index]
        }
        xAxis.gridColor = UIColor.lightGray.withAlphaComponent(0.5)
        xAxis.gridLineWidth = 0.5
        xAxis.gridLineDashLengths = [2, 2]

        let deltas = (regularPoints + dextroPoints).map { $0.y }
        // Round outwards to half units and keep zero visible even for one-sided data.
        let lower = min(-0.5, floor((deltas.min() ?? 0) * 2) / 2)
        let upper = max(0.5, ceil((deltas.max() ?? 0) * 2) / 2)
        let yAxis = timeChartView.leftAxis
        yAxis.axisMinimum = lower - 0.15
        yAxis.axisMaximum = upper + 0.15
        yAxis.granularity = 0.5
        yAxis.granularityEnabled = true
        yAxis.setLabelCount(6, force: false)
        yAxis.valueFormatter = DefaultAxisValueFormatter { value, _ in
            abs(value) < 0.001 ? "0.0" : String(format: "%+.1f", value)
        }
        // Explicit lines keep the half-unit grid exact even when Charts thins axis labels.
        yAxis.drawGridLinesEnabled = false
        yAxis.removeAllLimitLines()
        yAxis.drawLimitLinesBehindDataEnabled = true
        for value in stride(from: lower, through: upper, by: 0.5) {
            let line = ChartLimitLine(limit: value)
            let isZero = abs(value) < 0.001
            line.lineColor = UIColor.lightGray.withAlphaComponent(isZero ? 0.8 : 0.5)
            line.lineWidth = isZero ? 1.2 : 0.5
            line.lineDashLengths = isZero ? [] : [2, 2]
            yAxis.addLimitLine(line)
        }

        timeChartView.extraTopOffset = 20
        timeChartView.data = ScatterChartData(dataSets: [regular, dextro])
        timeChartView.notifyDataSetChanged()
        timeChartView.setNeedsDisplay()
    }
}
