import SwiftUI
import UIKit
import Charts

// MARK: - Real CR + TITR Line Chart

@available(iOS 26.0, *)
struct RealCRandTITRChartView: UIViewRepresentable {
    let rows: [DailyStatRow]
    let showingTitrSummary: Bool

    func makeUIView(context: Context) -> UIView {
        let containerView = UIView()
        containerView.backgroundColor = .clear
        containerView.isUserInteractionEnabled = true

        let chartView = LineChartView()
        chartView.backgroundColor = .clear

        // Plot-area background (only inside the data/grid rect, not outside axes/labels)
        chartView.drawGridBackgroundEnabled = true
        chartView.gridBackgroundColor = UIColor.systemBackground.withAlphaComponent(0.5)
        chartView.drawBordersEnabled = false

        chartView.chartDescription.enabled = false
        chartView.legend.enabled = false

        chartView.isUserInteractionEnabled = true
        chartView.drawMarkers = true

        // Disable zoom/scale
        chartView.pinchZoomEnabled = false
        chartView.doubleTapToZoomEnabled = false
        chartView.scaleXEnabled = false
        chartView.scaleYEnabled = false

        // Highlight on tap
        chartView.highlightPerTapEnabled = true

        // X axis
        let xAxis = chartView.xAxis
        xAxis.labelPosition = .bottom
        xAxis.drawAxisLineEnabled = false
        xAxis.drawGridLinesEnabled = true
        xAxis.gridLineWidth = 0.5
        xAxis.gridColor = NSUIColor.label.withAlphaComponent(0.15)
        xAxis.granularityEnabled = true
        xAxis.granularity = 1

        // Left axis: TITR/TIR 0–100
        let leftAxis = chartView.leftAxis
        leftAxis.drawAxisLineEnabled = false
        leftAxis.drawGridLinesEnabled = true
        leftAxis.gridLineWidth = 0.5
        leftAxis.gridColor = NSUIColor.label.withAlphaComponent(0.12)
        leftAxis.axisMinimum = 0
        leftAxis.axisMaximum = 100
        leftAxis.granularityEnabled = true
        leftAxis.granularity = 20
        leftAxis.labelCount = 6
        leftAxis.valueFormatter = RealCRLeftAxisFormatter()

        // Right axis: Real CR (dynamic)
        let rightAxis = chartView.rightAxis
        rightAxis.drawAxisLineEnabled = false
        rightAxis.drawGridLinesEnabled = false
        rightAxis.axisMinimum = 0

        // Use a dedicated marker for this chart
        chartView.marker = RealCRandTITRMarker(font: .systemFont(ofSize: 11, weight: .semibold))

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
        guard let chartView = containerView.subviews.first as? LineChartView else { return }

        let sorted = rows.sorted { $0.date < $1.date }
        let n = sorted.count

        guard n > 0 else {
            chartView.data = nil
            chartView.notifyDataSetChanged()
            chartView.setNeedsDisplay()
            return
        }

        // Prepare x labels dd/MM with <= 7 labels (evenly spread)
        let dateFormatter: DateFormatter = {
            let df = DateFormatter()
            df.dateFormat = "dd/MM"
            return df
        }()
        let labels = sorted.map { dateFormatter.string(from: $0.date) }

        let shownIndices: Set<Int> = {
            guard n > 0 else { return [] }
            if n <= 7 { return Set(0..<n) }

            // Aim for ~7 shown indices evenly spread
            var out: [Int] = []
            out.reserveCapacity(7)
            for i in 0..<7 {
                let t = Double(i) / 6.0
                let idx = Int((t * Double(n - 1)).rounded())
                out.append(max(0, min(n - 1, idx)))
            }

            // De-dupe
            var seen = Set<Int>()
            var unique: [Int] = []
            for i in out where seen.insert(i).inserted {
                unique.append(i)
            }

            // Fill if fewer than 7
            var cursor = 0
            while unique.count < 7 && unique.count < n {
                if !seen.contains(cursor) {
                    unique.append(cursor)
                    seen.insert(cursor)
                }
                cursor += 1
            }

            return Set(unique)
        }()

        // TITR/TIR (%) on left axis
        let leftPercentEntries: [ChartDataEntry] = sorted.enumerated().compactMap { idx, row in
            let percent = showingTitrSummary ? row.tightRangePercent : row.timeInRangePercent
            guard let percent else { return nil }
            return ChartDataEntry(x: Double(idx), y: percent)
        }

        // Real CR on right axis: carbs / (tdd - profileBasal), rounded to 1 decimal
        let crEntries: [ChartDataEntry] = sorted.enumerated().compactMap { idx, row in
            guard
                let carbs = row.totalCarbs,
                let tdd = row.insulinTDD,
                let profileBasal = row.profileBasal
            else { return nil }

            let denominator = tdd - profileBasal
            guard denominator > 0 else { return nil }

            let realCR = carbs / denominator
            let rounded = (realCR * 10).rounded() / 10
            return ChartDataEntry(x: Double(idx), y: rounded)
        }

        // Right axis max
        let maxCR = max(0, crEntries.map { $0.y }.max() ?? 0)
        let rightMax = max(1, maxCR * 1.12)
        chartView.rightAxis.axisMaximum = rightMax
        chartView.rightAxis.labelCount = 5

        // Data sets styling
        let titrSet = LineChartDataSet(entries: leftPercentEntries, label: (showingTitrSummary ? "TITR" : "TIR"))
        titrSet.axisDependency = .left
        titrSet.colors = [NSUIColor.systemGreen]
        titrSet.lineWidth = 1.5
        titrSet.drawCirclesEnabled = true
        titrSet.circleRadius = 5

        // Conditional TITR/TIR point colors:
            // TITR -> green if >= 50%
            // TIR  -> green if >= 70%
            let threshold: Double = showingTitrSummary ? 50.0 : 70.0
            let titrCircleColors: [NSUIColor] = leftPercentEntries.map { entry in
                (entry.y >= threshold) ? NSUIColor.systemGreen : NSUIColor.systemRed
            }
        titrSet.circleColors = titrCircleColors

        titrSet.drawValuesEnabled = false
        titrSet.mode = .linear
        titrSet.highlightEnabled = true
        titrSet.drawCircleHoleEnabled = true
        titrSet.circleHoleRadius = 2
        titrSet.circleHoleColor = NSUIColor.white
        titrSet.drawHorizontalHighlightIndicatorEnabled = false
        titrSet.drawVerticalHighlightIndicatorEnabled = false

        let crSet = LineChartDataSet(entries: crEntries, label: "CR")
        crSet.axisDependency = .right
        crSet.colors = [NSUIColor.systemMint]
        crSet.lineWidth = 1.5
        crSet.drawCirclesEnabled = true
        crSet.circleRadius = 5
        crSet.circleColors = [NSUIColor.systemMint]
        crSet.drawValuesEnabled = false
        crSet.mode = .linear
        crSet.highlightEnabled = true
        crSet.drawCircleHoleEnabled = true
        crSet.circleHoleRadius = 2
        crSet.circleHoleColor = NSUIColor.white
        crSet.drawHorizontalHighlightIndicatorEnabled = false
        crSet.drawVerticalHighlightIndicatorEnabled = false

        let data = LineChartData(dataSets: [titrSet, crSet])

        // X-axis labels: keep <= 7 behavior, hide for larger ranges
        if n <= 7 {
            chartView.xAxis.drawLabelsEnabled = true
            chartView.xAxis.valueFormatter = RealCRXAxisFormatter(labels: labels, shownIndices: shownIndices)
            chartView.xAxis.setLabelCount(n, force: true)
        } else {
            chartView.xAxis.drawLabelsEnabled = false
            chartView.xAxis.valueFormatter = DefaultAxisValueFormatter(block: { _, _ in "" })
            chartView.xAxis.setLabelCount(0, force: true)
        }

        // Ensure marker knows which chart it belongs to
        (chartView.marker as? MarkerView)?.chartView = chartView

        chartView.data = data
        chartView.notifyDataSetChanged()
        chartView.setNeedsDisplay()
    }
}

private final class RealCRXAxisFormatter: AxisValueFormatter {
    private let labels: [String]
    private let shownIndices: Set<Int>

    init(labels: [String], shownIndices: Set<Int>) {
        self.labels = labels
        self.shownIndices = shownIndices
    }

    func stringForValue(_ value: Double, axis: AxisBase?) -> String {
        let idx = Int(value.rounded())
        guard idx >= 0, idx < labels.count else { return "" }
        return shownIndices.contains(idx) ? labels[idx] : ""
    }
}

private final class RealCRLeftAxisFormatter: AxisValueFormatter {
    func stringForValue(_ value: Double, axis: AxisBase?) -> String {
        // Show 0, 20, 40, 60, 80, 100
        let rounded = Int(value.rounded())
        if rounded % 20 != 0 { return "" }
        if rounded < 0 || rounded > 100 { return "" }
        return "\(rounded)"
    }
}

private final class RealCRandTITRMarker: MarkerView {
    private let label = UILabel()

    init(font: UIFont) {
        super.init(frame: CGRect(x: 0, y: 0, width: 78, height: 30))

        label.font = font
        label.textAlignment = .center
        label.textColor = .white
        backgroundColor = UIColor.systemGray4.withAlphaComponent(0.8)
        layer.cornerRadius = 6
        layer.borderWidth = 1
        layer.borderColor = UIColor.label.cgColor
        clipsToBounds = true

        addSubview(label)

        label.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: topAnchor),
            label.bottomAnchor.constraint(equalTo: bottomAnchor),
            label.leadingAnchor.constraint(equalTo: leadingAnchor),
            label.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
    }

    required init?(coder: NSCoder) { nil }

    override func refreshContent(entry: ChartDataEntry, highlight: Highlight) {
        let value = entry.y

        // DataSets are added as: [TITR, Real CR]
        if highlight.dataSetIndex == 0 {
            // TITR
            label.text = String(format: "%.0f %%", value)
        } else {
            // Real CR
            label.text = String(format: "%.1f g/E", value)
        }

        layoutIfNeeded()
    }

    override func offsetForDrawing(atPoint point: CGPoint) -> CGPoint {
        // Center above the touched point
        let size = bounds.size
        return CGPoint(x: -size.width / 2, y: -size.height + 12)
    }
}

