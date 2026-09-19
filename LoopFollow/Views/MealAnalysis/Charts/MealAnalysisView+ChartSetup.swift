import UIKit
import Charts

extension MealAnalysisView {
    // MARK: - BG chart helpers
    func setupBGChart() {
        bgChartView.delegate = self
        bgChartView.chartDescription.enabled = false
        bgChartView.legend.enabled = false
        bgChartView.rightAxis.enabled = false
        bgChartView.pinchZoomEnabled = false
        bgChartView.doubleTapToZoomEnabled = false
        bgChartView.dragEnabled = false
        bgChartView.highlightPerTapEnabled = true
        bgChartView.scaleXEnabled = false
        bgChartView.scaleYEnabled = false
        bgChartView.drawGridBackgroundEnabled = true
        bgChartView.gridBackgroundColor = NSUIColor.systemBackground.withAlphaComponent(0.5)
        bgChartView.drawOrder = [CombinedChartView.DrawOrder.line.rawValue, CombinedChartView.DrawOrder.scatter.rawValue]

        // Y axis 0‑24 mmol
        let y = bgChartView.leftAxis
        y.axisMinimum = 0
        y.axisMaximum = 24
        y.spaceTop = 0.02   // small headroom so dots at 23 are visible
        y.labelCount = 6
        y.gridColor = NSUIColor.lightGray.withAlphaComponent(0.4)
        y.gridLineWidth = 0.5
        y.gridLineDashLengths = [2,2]

        // threshold lines with bespoke colors using user-defined values
        let lowMmol = Double(UserDefaultsRepository.lowLine.value) / 18.0182
        let highMmol = Double(UserDefaultsRepository.highLine.value) / 18.0182

        let thresholds: [(limit: Double, color: UIColor)] = [
            (lowMmol, UIColor.red.withAlphaComponent(0.8)),
            (highMmol, UIColor.purple.withAlphaComponent(1.0))
        ]

        for (limit, color) in thresholds {
            let ll = ChartLimitLine(limit: limit)
            ll.lineColor   = color
            ll.lineDashLengths = [1, 1]
            ll.lineWidth   = 2
            //ll.lineDashLengths = [4, 2]    // optional: dashed look
            //ll.label       = String(format: "%.1f", limit)
            ll.valueTextColor = color     // so the label matches
            y.addLimitLine(ll)
        }

        // Draw limit lines behind the data so the BG line stays on top
        y.drawLimitLinesBehindDataEnabled = true

        // X axis
        let x = bgChartView.xAxis
        x.labelPosition = .bottom
        x.gridColor = NSUIColor.lightGray.withAlphaComponent(0.4)
        x.gridLineWidth = 0.5
        x.gridLineDashLengths = [2,2]
        x.valueFormatter = self
        // Avoid clipping of last X‑label and give the line some breathing room
        x.avoidFirstLastClippingEnabled = false
        bgChartView.extraRightOffset = 16
    }
    
    /// Same hue interpolation as in graphs.swift, but thresholds are converted once into mmol/L
    func setBGColorForMmol(_ mmolValue: Double) -> NSUIColor {
        // 1) Grab your mg/dL thresholds
        let minMgdl    = Double(UserDefaultsRepository.alertUrgentLowBG.value)
        let targetMgdl = Double(UserDefaultsRepository.targetLine.value)
        let maxMgdl    = Double(UserDefaultsRepository.alertUrgentHighBG.value)

        // 2) Convert once to mmol/L
        let factor = 18.0182
        let minMmol    = minMgdl    / factor
        let targetMmol = targetMgdl / factor
        let maxMmol    = maxMgdl    / factor

        // 3) Hues
        let redHue    : CGFloat = 0.0   / 360.0
        let greenHue  : CGFloat = 120.0 / 360.0
        let purpleHue : CGFloat = 270.0 / 360.0

        // 4) Interpolate
        let hue: CGFloat
        if mmolValue <= minMmol {
            hue = redHue
        } else if mmolValue >= maxMmol {
            hue = purpleHue
        } else if mmolValue <= targetMmol {
            let ratio = CGFloat((mmolValue - minMmol) / (targetMmol - minMmol))
            hue = redHue + ratio * (greenHue - redHue)
        } else {
            let ratio = CGFloat((mmolValue - targetMmol) / (maxMmol - targetMmol))
            hue = greenHue + ratio * (purpleHue - greenHue)
        }

        return UIColor(hue: hue, saturation: 0.9, brightness: 0.9, alpha: 1.0)
    }


    // MARK: - Chart popup handler (for value selection)
    func chartValueSelected(_ chartView: ChartViewBase, entry: ChartDataEntry, highlight: Highlight) {
        let title: String
        if let s = entry.data as? String {
            title = s
        } else {
            title = String(format: "%.2f", entry.y)
        }
        let alert = UIAlertController(title: title, message: "", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        present(alert, animated: true, completion: nil)
    }
}

extension MealAnalysisView: AxisValueFormatter {
    func stringForValue(_ value: Double, axis: AxisBase?) -> String {
        let date = startTime.addingTimeInterval(value * 3600)
        let totalHours = endTime.timeIntervalSince(startTime) / 3600.0

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "sv_SE")

        if totalHours <= 3 * 24 {
            // Upp till 3 dygn: visa klockslag
            formatter.dateFormat = "HH:mm"
        } else {
            // >3 dygn: visa datum (enligt X-axis granularity/labelCount)
            formatter.dateFormat = "dd/MM"
        }

        return formatter.string(from: date)
    }
}

