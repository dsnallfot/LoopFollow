import UIKit
import Charts

extension LowTreatmentsStatsViewController {
    func loadLowAndBgChartData() {
        guard !selectedDays.isEmpty else {
            scatterChartView.data = nil
            scatterChartView.setNeedsDisplay()
            return
        }

        let cal = Calendar.current
        // Referens = periodens första dag kl 00:00
        let referenceStart = cal.startOfDay(for: selectedDays.first!)
        let now = Date()
        let hoursSinceStartNow = max(0.0, now.timeIntervalSince(referenceStart) / 3600.0)

        // Sortera Dextro-behandlingar kronologiskt (äldst -> nyast)
        let sortedDextro = zip(selectedTreatmentDates, selectedTreatmentGrams)
            .sorted { $0.0 < $1.0 }

        // Sortera BG Checks kronologiskt (äldst -> nyast)
        let sortedBG = zip(selectedBGCheckDates, selectedBGCheckMmol)
            .sorted { $0.0 < $1.0 }

        // Dextro-punkter: vänster y-axel (g)
        var dextroEntries: [ChartDataEntry] = []
        var maxGrams: Double = 0
        for (date, grams) in sortedDextro {
            guard passesTimeFilter(date) else { continue }
            // x = antal timmar sedan periodens start (ger granularitet ner på minuter)
            let hoursSinceStart = date.timeIntervalSince(referenceStart) / 3600.0
            dextroEntries.append(ChartDataEntry(x: hoursSinceStart, y: grams))
            if grams > maxGrams { maxGrams = grams }
        }

        // Stick-punkter: höger y-axel (mmol/L)
        var bgEntries: [ChartDataEntry] = []
        var maxMmol: Double = 0
        for (date, mmol) in sortedBG {
            guard passesTimeFilter(date) else { continue }
            let hoursSinceStart = date.timeIntervalSince(referenceStart) / 3600.0
            bgEntries.append(ChartDataEntry(x: hoursSinceStart, y: mmol))
            if mmol > maxMmol { maxMmol = mmol }
        }


        let dextroSet = ScatterChartDataSet(entries: dextroEntries, label: "Dextro (g)")
        dextroSet.axisDependency = .left
        dextroSet.setColor(.black)
        dextroSet.setScatterShape(.circle)
        dextroSet.scatterShapeSize = 7
        dextroSet.drawValuesEnabled = false
        dextroSet.scatterShapeHoleRadius = 3
        dextroSet.scatterShapeHoleColor = .white
        dextroSet.highlightEnabled = true
        dextroSet.setDrawHighlightIndicators(false)

        let bgSet = ScatterChartDataSet(entries: bgEntries, label: "Fingerstick (mmol/L)")
        bgSet.axisDependency = .right
        bgSet.setColor(.black)
        bgSet.setScatterShape(.circle)
        bgSet.scatterShapeSize = 7
        bgSet.drawValuesEnabled = false
        bgSet.scatterShapeHoleRadius = 3
        bgSet.scatterShapeHoleColor = .systemRed
        bgSet.highlightEnabled = true
        bgSet.setDrawHighlightIndicators(false)

        let data = ScatterChartData(dataSets: [dextroSet, bgSet])
        scatterChartView.data = data

        scatterChartView.drawGridBackgroundEnabled = true
        scatterChartView.gridBackgroundColor = NSUIColor.systemBackground.withAlphaComponent(0.5)

        // Marker med tre rader text för dextro/fingerstick
        let marker = DextroBgMarker(referenceDate: referenceStart)
        marker.chartView = scatterChartView
        scatterChartView.marker = marker

        // --- Custom legend (centrerad under grafen) --- //
        let legend = scatterChartView.legend
        legend.enabled = true
        legend.drawInside = false
        legend.orientation = .horizontal
        legend.verticalAlignment = .bottom
        legend.horizontalAlignment = .center
        legend.xEntrySpace = 12
        legend.yEntrySpace = 6
        legend.formToTextSpace = 6
        legend.yOffset = 8
        // Lite extra luft mellan plot-ytan och legend (yOffset påverkar inte alltid layouten)
        scatterChartView.extraBottomOffset = 4

        let dextroLegendEntry = LegendEntry(label: "Dextro (g)")
        dextroLegendEntry.form = .circle
        dextroLegendEntry.formSize = 8
        dextroLegendEntry.formColor = .white

        let bgLegendEntry = LegendEntry(label: "Fingerstick (mmol/L)")
        bgLegendEntry.form = .circle
        bgLegendEntry.formSize = 8
        bgLegendEntry.formColor = .systemRed

        legend.setCustom(entries: [dextroLegendEntry, bgLegendEntry])

        // X-axel: värden i timmar från periodens start, formatteras till datum
        let xAxis = scatterChartView.xAxis
        xAxis.labelPosition = .bottom
        xAxis.granularity = 24.0   // ca en etikett per dygn
        xAxis.granularityEnabled = true
        xAxis.valueFormatter = DateAxisFormatter(referenceDate: referenceStart)
        xAxis.setLabelCount(min(6, selectedDays.count), force: false)
        xAxis.axisMinimum = 0.0
        xAxis.axisMaximum = hoursSinceStartNow

        let leftAxis = scatterChartView.leftAxis
        leftAxis.axisMinimum = 0
        let maxYLeft = max(1, maxGrams)
        leftAxis.axisMaximum = maxYLeft * 1.2
        // Enhet på vänster y-axel
        leftAxis.valueFormatter = DefaultAxisValueFormatter { value, _ in
            String(format: "%.0f g", value)
        }

        let rightAxis = scatterChartView.rightAxis
        rightAxis.enabled = true
        rightAxis.axisMinimum = 0
        let maxYRight = max(1, maxMmol)
        rightAxis.axisMaximum = maxYRight * 1.2
        // Enhet på höger y-axel
        rightAxis.valueFormatter = DefaultAxisValueFormatter { value, _ in
            String(format: "%.0f mmol", value)
        }
        rightAxis.labelTextColor = .systemRed

        let gridLineColor = UIColor.lightGray.withAlphaComponent(0.5)
        xAxis.gridColor = gridLineColor
        xAxis.gridLineWidth = 0.5
        xAxis.gridLineDashLengths = [2, 2]

        leftAxis.gridColor = .clear
        leftAxis.gridLineWidth = 0.5
        leftAxis.gridLineDashLengths = [2, 2]

        rightAxis.gridColor = gridLineColor
        rightAxis.gridLineWidth = 0.5
        rightAxis.gridLineDashLengths = [2, 2]

        scatterChartView.notifyDataSetChanged()
        scatterChartView.setNeedsDisplay()
    }

}
