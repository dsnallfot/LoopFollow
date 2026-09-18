import SwiftUI
import UIKit
import Charts

// MARK: - DailyCarbsTDDBarChartView

@available(iOS 26.0, *)
struct DailyCarbsTDDBarChartView: UIViewRepresentable {
    let rows: [DailyStatRow]

    func makeUIView(context: Context) -> UIView {
        // IMPORTANT: we need touch handling for highlight + marker.
        // NonInteractiveContainerView blocks touches, so use a plain UIView.
        let containerView = UIView()
        containerView.backgroundColor = .clear
        containerView.isUserInteractionEnabled = true

        let chartView = BarChartView()
        chartView.backgroundColor = .clear
        // Plot-area background (only inside the data/grid rect, not outside axes/labels)
        chartView.drawGridBackgroundEnabled = true
        chartView.gridBackgroundColor = UIColor.systemBackground.withAlphaComponent(0.5)
        chartView.drawBordersEnabled = false

        chartView.rightAxis.enabled = true
        chartView.leftAxis.enabled = true

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
        chartView.highlightFullBarEnabled = false

        // Axes
        let xAxis = chartView.xAxis
        xAxis.labelPosition = .bottom
        xAxis.drawAxisLineEnabled = false
        xAxis.drawGridLinesEnabled = true
        xAxis.gridLineWidth = 0.5
        xAxis.gridColor = NSUIColor.label.withAlphaComponent(0.15)
        xAxis.granularityEnabled = true
        // Important for grouped bars: center labels under each day-group
        xAxis.centerAxisLabelsEnabled = true

        let leftAxis = chartView.leftAxis
        leftAxis.drawAxisLineEnabled = false
        leftAxis.drawGridLinesEnabled = false
        leftAxis.axisMinimum = 0

        let rightAxis = chartView.rightAxis
        rightAxis.drawAxisLineEnabled = false
        rightAxis.drawGridLinesEnabled = false
        rightAxis.axisMinimum = 0

        // Marker
        chartView.marker = DailyBarsMarker(font: .systemFont(ofSize: 11, weight: .semibold))

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

        let calendar = Calendar.current
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

        let labelIndices: [Int] = {
            guard n > 0 else { return [] }
            if n <= 7 { return Array(0..<n) }

            // Aim for exactly 7 indices, evenly spread across 0...(n-1)
            var out: [Int] = []
            out.reserveCapacity(7)
            for i in 0..<7 {
                let t = Double(i) / 6.0
                let idx = Int((t * Double(n - 1)).rounded())
                out.append(max(0, min(n - 1, idx)))
            }

            // De-dupe while preserving order
            var seen = Set<Int>()
            var unique: [Int] = []
            for i in out {
                if seen.insert(i).inserted { unique.append(i) }
            }

            // If rounding caused fewer than 7, fill by stepping forward
            var cursor = 0
            while unique.count < 7 && unique.count < n {
                if !seen.contains(cursor) {
                    unique.append(cursor)
                    seen.insert(cursor)
                }
                cursor += 1
            }
            return unique.sorted()
        }()


        // Build entries
        let tddEntries: [BarChartDataEntry] = sorted.enumerated().map { idx, row in
            BarChartDataEntry(x: Double(idx), y: row.insulinTDD ?? 0)
        }
        let carbsEntries: [BarChartDataEntry] = sorted.enumerated().map { idx, row in
            BarChartDataEntry(x: Double(idx), y: row.totalCarbs ?? 0)
        }

        // Y axis ranges with top margin
        let maxTDD = (sorted.compactMap { $0.insulinTDD }.max() ?? 0)
        let maxCarbs = (sorted.compactMap { $0.totalCarbs }.max() ?? 0)
        let leftMax = max(1, maxTDD * 1.12)
        let rightMax = max(1, maxCarbs * 1.12)

        chartView.leftAxis.axisMaximum = leftMax
        chartView.rightAxis.axisMaximum = rightMax

        // Data sets
        let tddSet = BarChartDataSet(entries: tddEntries, label: "TDD")
        tddSet.axisDependency = .left
        tddSet.colors = [NSUIColor.insulin.withAlphaComponent(0.8)]
        tddSet.drawValuesEnabled = false
        tddSet.highlightEnabled = true

        let carbsSet = BarChartDataSet(entries: carbsEntries, label: "KH")
        carbsSet.axisDependency = .right
        carbsSet.colors = [NSUIColor.carbs.withAlphaComponent(0.8)]
        carbsSet.drawValuesEnabled = false
        carbsSet.highlightEnabled = true

        // Grouped bars
        let data = BarChartData(dataSets: [tddSet, carbsSet])
        let groupSpace = 0.26
        let barSpace = 0.04
        let barWidth = (1.0 - groupSpace) / 2.0 - barSpace
        data.barWidth = barWidth

        let startX = 0.0
        data.groupBars(fromX: startX, groupSpace: groupSpace, barSpace: barSpace)

        let groupWidth = data.groupWidth(groupSpace: groupSpace, barSpace: barSpace)

        // X-axis: one tick per day-group
        chartView.xAxis.granularity = groupWidth
        chartView.xAxis.axisMinimum = startX
        chartView.xAxis.axisMaximum = startX + groupWidth * Double(n)

        // Labels (<= 7 shown, evenly spread)
        // X-axis labels
        // Keep the existing behavior for <= 7 days (looks perfect), but hide labels entirely for larger ranges.
        if n <= 7 {
            chartView.xAxis.drawLabelsEnabled = true
            chartView.xAxis.valueFormatter = DailyBarsXAxisFormatter(
                labels: labels,
                shownIndices: Set(labelIndices),
                startX: startX,
                groupWidth: groupWidth
            )
            chartView.xAxis.setLabelCount(n, force: true)
        } else {
            // Hide labels for 14/30/90 etc. to avoid odd spacing artifacts.
            chartView.xAxis.drawLabelsEnabled = false
            chartView.xAxis.valueFormatter = DefaultAxisValueFormatter(block: { _, _ in "" })
            chartView.xAxis.setLabelCount(0, force: true)
        }

        chartView.xAxis.setLabelCount(min(7, n), force: false)

        // Ensure marker knows which chart it belongs to
        (chartView.marker as? MarkerView)?.chartView = chartView

        chartView.data = data
        chartView.notifyDataSetChanged()
        chartView.setNeedsDisplay()
    }
}

private final class DailyBarsMarker: MarkerView {
    private let label = UILabel()

    init(font: UIFont) {
        super.init(frame: CGRect(x: 0, y: 0, width: 60, height: 30))

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
        if highlight.dataSetIndex == 0 {
            // TDD
            label.text = String(format: "%.1f E", value)
        } else {
            // KH
            label.text = String(format: "%.0f g", value)
        }
        layoutIfNeeded()
    }

    override func offsetForDrawing(atPoint point: CGPoint) -> CGPoint {
        // Center above the touched bar
        let size = bounds.size
        return CGPoint(x: -size.width / 2, y: -size.height + 12)
    }
}

private final class DailyBarsXAxisFormatter: AxisValueFormatter {
    private let labels: [String]
    private let shownIndices: Set<Int>
    private let startX: Double
    private let groupWidth: Double

    init(labels: [String], shownIndices: Set<Int>, startX: Double, groupWidth: Double) {
        self.labels = labels
        self.shownIndices = shownIndices
        self.startX = startX
        self.groupWidth = max(groupWidth, 0.0001)
    }

    func stringForValue(_ value: Double, axis: AxisBase?) -> String {
        // With centered axis labels + grouped bars, x values are at day-group centers.
        // Map axis x -> day index using groupWidth.
        let raw = (value - startX) / groupWidth
        let idx = Int(raw.rounded())
        guard idx >= 0, idx < labels.count else { return "" }
        return shownIndices.contains(idx) ? labels[idx] : ""
    }
}

