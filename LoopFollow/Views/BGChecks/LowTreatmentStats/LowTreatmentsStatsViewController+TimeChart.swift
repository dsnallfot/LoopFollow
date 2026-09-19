import UIKit
import Charts

extension LowTreatmentsStatsViewController {
    func loadTreatmentTimeChartData() {
        guard !selectedDays.isEmpty else {
            timeChartView.data = nil
            timeChartView.setNeedsDisplay()
            return
        }

        let cal = Calendar.current

        // Index per dag för x-position
        var indexByDay: [Date: Int] = [:]
        for (idx, d) in selectedDays.enumerated() {
            indexByDay[cal.startOfDay(for: d)] = idx
        }

        func hourOfDay(for date: Date) -> Double {
            let comps = cal.dateComponents([.hour, .minute, .second], from: date)
            let h = Double(comps.hour ?? 0)
            let m = Double(comps.minute ?? 0)
            let s = Double(comps.second ?? 0)
            return h + (m / 60.0) + (s / 3600.0)
        }

        // Vita punkter = alla dextro, lila = dextro med fingerstick (hasBGCheckNearby == true)
        var allPoints: [ChartDataEntry] = []
        var purplePoints: [ChartDataEntry] = []
        allPoints.reserveCapacity(selectedTreatmentDates.count)
        purplePoints.reserveCapacity(selectedTreatmentDates.count)

        for i in selectedTreatmentDates.indices {
            let date = selectedTreatmentDates[i]
            guard passesTimeFilter(date) else { continue }

            let dayStart = cal.startOfDay(for: date)
            guard let dayIndex = indexByDay[dayStart] else { continue }

            let entry = ChartDataEntry(x: Double(dayIndex), y: hourOfDay(for: date))
            allPoints.append(entry)

            if i < selectedTreatmentHasBGCheck.count, selectedTreatmentHasBGCheck[i] {
                purplePoints.append(entry)
            }
        }

        // Viktigt: sortera entries för att undvika Charts-bug där punkter kan försvinna vid zoom/scroll
        allPoints.sort {
            if $0.x == $1.x { return $0.y < $1.y }
            return $0.x < $1.x
        }
        purplePoints.sort {
            if $0.x == $1.x { return $0.y < $1.y }
            return $0.x < $1.x
        }

        let whiteColor = UIColor.white.withAlphaComponent(0.90)
        let purpleColor = UIColor.systemPurple.withAlphaComponent(0.95)

        let dsAll = ScatterChartDataSet(entries: allPoints, label: "Dextrobehandling")
        dsAll.setColor(whiteColor)
        dsAll.setScatterShape(.circle)
        dsAll.scatterShapeSize = 7
        dsAll.drawValuesEnabled = false

        let dsPurple = ScatterChartDataSet(entries: purplePoints, label: "Dextro med fingerstick")
        dsPurple.setColor(purpleColor)
        dsPurple.setScatterShape(.circle)
        dsPurple.scatterShapeSize = 7
        dsPurple.drawValuesEnabled = false

        // Lila sist så de syns ovanpå vitt
        timeChartView.data = ScatterChartData(dataSets: [dsAll, dsPurple])
        timeChartView.autoScaleMinMaxEnabled = false
        timeChartView.notifyDataSetChanged()

        timeChartView.drawGridBackgroundEnabled = true
        timeChartView.gridBackgroundColor = NSUIColor.systemBackground.withAlphaComponent(0.5)

        // Custom legend: vit cirkel + lila cirkel
        let legend = timeChartView.legend
        legend.enabled = true
        legend.drawInside = false
        legend.orientation = .horizontal
        legend.verticalAlignment = .bottom
        legend.horizontalAlignment = .center
        legend.xEntrySpace = 12
        legend.formToTextSpace = 6
        legend.yOffset = 6

        let e1 = LegendEntry(label: "Dextrobehandling")
        e1.form = .circle
        e1.formSize = 8
        e1.formColor = whiteColor

        let e2 = LegendEntry(label: "Dextro med fingerstick")
        e2.form = .circle
        e2.formSize = 8
        e2.formColor = purpleColor

        legend.setCustom(entries: [e1, e2])
        timeChartView.extraBottomOffset = 8

        // X-axis labels = datum (dd/MM)
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

        // Y-axel = timmar 0–24 (dashad grid) + solida huvudlinjer 00/06/12/18/24
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
