import SwiftUI
import UIKit
import Charts

@available(iOS 17.0, *)
@available(iOS 17.0, *)
struct TrainingStatsBarChartView: UIViewRepresentable {
    let dayTotals: [TrainingStatsView.DayTotal]

    func makeUIView(context: Context) -> UIView {
        let containerView = UIView()
        containerView.backgroundColor = .clear
        containerView.isUserInteractionEnabled = true

        let chartView = BarChartView()
        chartView.backgroundColor = .clear
        chartView.drawGridBackgroundEnabled = true
        chartView.gridBackgroundColor = UIColor.systemBackground.withAlphaComponent(0.5)
        chartView.drawBordersEnabled = false
        chartView.chartDescription.enabled = false

        chartView.legend.enabled = true
        chartView.legend.verticalAlignment = .bottom
        chartView.legend.horizontalAlignment = .center
        chartView.legend.orientation = .horizontal
        chartView.legend.drawInside = false
        chartView.legend.yOffset = 8
        chartView.legend.textColor = .secondaryLabel
        chartView.legend.font = .systemFont(ofSize: 11, weight: .medium)

        chartView.rightAxis.enabled = false
        chartView.leftAxis.enabled = true

        chartView.isUserInteractionEnabled = true
        chartView.drawMarkers = false
        chartView.pinchZoomEnabled = false
        chartView.doubleTapToZoomEnabled = false
        chartView.scaleXEnabled = false
        chartView.scaleYEnabled = false
        chartView.highlightPerTapEnabled = false
        chartView.dragEnabled = false

        let xAxis = chartView.xAxis
        xAxis.labelPosition = .bottom
        xAxis.drawAxisLineEnabled = false
        xAxis.drawGridLinesEnabled = true
        xAxis.gridLineWidth = 0.5
        xAxis.gridColor = NSUIColor.label.withAlphaComponent(0.15)
        xAxis.granularityEnabled = true
        xAxis.centerAxisLabelsEnabled = false
        xAxis.labelTextColor = .secondaryLabel
        xAxis.labelFont = .systemFont(ofSize: 10, weight: .medium)

        let leftAxis = chartView.leftAxis
        leftAxis.drawAxisLineEnabled = false
        leftAxis.drawGridLinesEnabled = true
        leftAxis.gridLineWidth = 0.5
        leftAxis.gridColor = NSUIColor.label.withAlphaComponent(0.12)
        leftAxis.axisMinimum = 0
        leftAxis.labelTextColor = .secondaryLabel
        leftAxis.labelFont = .systemFont(ofSize: 10, weight: .medium)
        leftAxis.valueFormatter = DefaultAxisValueFormatter(block: { value, _ in
            let totalMinutes = Int(value.rounded())
            return "\(totalMinutes)"
        })

        containerView.addSubview(chartView)
        chartView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            chartView.topAnchor.constraint(equalTo: containerView.topAnchor),
            chartView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            chartView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            chartView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])

        return containerView
    }

    func updateUIView(_ containerView: UIView, context: Context) {
        guard let chartView = containerView.subviews.first as? BarChartView else { return }

        let sorted = dayTotals.sorted { $0.date < $1.date }
        let count = sorted.count

        guard count > 0 else {
            chartView.data = nil
            chartView.notifyDataSetChanged()
            chartView.setNeedsDisplay()
            return
        }

        let dateFormatter: DateFormatter = {
            let df = DateFormatter()
            df.locale = Locale(identifier: "sv_SE")
            df.dateFormat = "dd/M"
            return df
        }()

        let labels = sorted.map { dateFormatter.string(from: $0.date) }


        let entries: [BarChartDataEntry] = sorted.enumerated().map { idx, item in
            BarChartDataEntry(
                x: Double(idx),
                yValues: [item.metaQuestMinutes, item.otherTrainingMinutes, item.gympaMinutes, item.highActivityMinutes]
            )
        }

        let maxValue = sorted.map { $0.minutes }.max() ?? 0
        let axisStep: Double = maxValue <= 180 ? 30 : 60
        let paddedMaxValue = maxValue * 1.12
        let axisMaximum = max(axisStep, ceil(paddedMaxValue / axisStep) * axisStep)
        chartView.leftAxis.axisMaximum = axisMaximum
        chartView.leftAxis.axisMinimum = 0
        chartView.leftAxis.granularityEnabled = true
        chartView.leftAxis.granularity = axisStep
        chartView.leftAxis.labelCount = Int(axisMaximum / axisStep) + 1
        chartView.leftAxis.forceLabelsEnabled = true

        let dataSet = BarChartDataSet(entries: entries, label: "Träning")
        dataSet.colors = [
            NSUIColor.systemGreen,                         // Meta Quest
            NSUIColor.systemOrange.withAlphaComponent(0.7), // Övrig träning
            NSUIColor.systemGreen.withAlphaComponent(0.6),  // Gympa
            NSUIColor.systemGreen.withAlphaComponent(0.3)   // Hög aktivitet
        ]
        dataSet.stackLabels = ["VR-spel", "Övrig träning", "Gympa", "Hög aktivitet"]
        dataSet.drawValuesEnabled = false
        dataSet.highlightEnabled = false

        let data = BarChartData(dataSet: dataSet)
        data.barWidth = 0.62

        chartView.xAxis.axisMinimum = -0.5
        chartView.xAxis.axisMaximum = Double(count) - 0.5
        chartView.xAxis.granularity = 1.0
        chartView.xAxis.granularityEnabled = true
        chartView.xAxis.valueFormatter = IndexAxisValueFormatter(values: labels)
        chartView.xAxis.setLabelCount(min(6, labels.count), force: false)

        let legendEntries: [LegendEntry] = [
            {
                let e = LegendEntry(label: "VR-spel")
                e.form = .square
                e.formColor = NSUIColor.systemGreen
                return e
            }(),
            {
                let e = LegendEntry(label: "Övrig träning")
                e.form = .square
                e.formColor = NSUIColor.systemOrange.withAlphaComponent(0.7)
                return e
            }(),
            {
                let e = LegendEntry(label: "Gympa")
                e.form = .square
                e.formColor = NSUIColor.systemGreen.withAlphaComponent(0.6)
                return e
            }(),
            {
                let e = LegendEntry(label: "Hög aktivitet")
                e.form = .square
                e.formColor = NSUIColor.systemGreen.withAlphaComponent(0.3)
                return e
            }()
        ]
        chartView.legend.setCustom(entries: legendEntries)

        chartView.data = data
        chartView.notifyDataSetChanged()
        chartView.setNeedsDisplay()
    }
}
