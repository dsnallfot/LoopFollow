import UIKit
import Charts

extension LowTreatmentsStatsViewController {
    /// Marker som visar tre rader text för Dextro respektive fingerstick i scatter-grafen.
    final class DextroBgMarker: MarkerView {

        private let label = UILabel()
        private let contentInsets = UIEdgeInsets(top: 6, left: 8, bottom: 6, right: 8)
        private let referenceDate: Date
        private let dateFormatter: DateFormatter

        init(referenceDate: Date) {
            self.referenceDate = referenceDate

            let df = DateFormatter()
            df.locale = Locale(identifier: "sv_SE")
            df.dateFormat = "yyyy-MM-dd HH:mm"
            self.dateFormatter = df

            super.init(frame: .zero)

            label.numberOfLines = 0
            label.font = .systemFont(ofSize: 12)
            label.textColor = .label

            addSubview(label)

            backgroundColor = UIColor.systemGray4.withAlphaComponent(0.8)
            layer.cornerRadius = 6
            layer.borderWidth = 1
            layer.borderColor = UIColor.label.cgColor
            clipsToBounds = true
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func refreshContent(entry: ChartDataEntry, highlight: Highlight) {
            guard
                let scatterData = chartView?.data as? ScatterChartData,
                highlight.dataSetIndex >= 0,
                highlight.dataSetIndex < scatterData.dataSetCount
            else {
                return
            }

            let dataSet = scatterData.dataSets[highlight.dataSetIndex]

            // BG (fingerstick) ligger på höger-axeln, dextro på vänster.
            let isFingerstick = dataSet.axisDependency == .right

            // x är antal timmar sedan periodens start
            let date = referenceDate.addingTimeInterval(entry.x * 3600.0)
            let dateString = dateFormatter.string(from: date)

            let line1: String
            let line2: String

            if isFingerstick {
                line1 = "Fingerstick"
                line2 = String(format: "%.1f mmol/L", entry.y)
            } else {
                line1 = "Dextro"
                line2 = String(format: "%.0f g kh", entry.y)
            }

            label.text = "\(line1)\n\(line2)\n\(dateString)"
            label.sizeToFit()

            let size = CGSize(
                width: label.bounds.width + contentInsets.left + contentInsets.right,
                height: label.bounds.height + contentInsets.top + contentInsets.bottom
            )
            bounds = CGRect(origin: .zero, size: size)

            label.frame = CGRect(
                x: contentInsets.left,
                y: contentInsets.top,
                width: size.width - contentInsets.left - contentInsets.right,
                height: size.height - contentInsets.top - contentInsets.bottom
            )

            layoutIfNeeded()

            // Centera markern över punkten och placera den strax ovanför
            let sizeMarker = bounds.size
            self.offset = CGPoint(
                x: -sizeMarker.width / 2.0,
                y: -sizeMarker.height - 8.0
            )

            super.refreshContent(entry: entry, highlight: highlight)
        }
    }
}
