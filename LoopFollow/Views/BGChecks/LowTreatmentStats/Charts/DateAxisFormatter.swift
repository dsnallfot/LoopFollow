import UIKit
import Charts

extension LowTreatmentsStatsViewController {
    /// Formatterar x-värden (timmar från periodens start) till datumsträngar på x-axeln.
    final class DateAxisFormatter: AxisValueFormatter {
        private let referenceDate: Date
        private let dateFormatter: DateFormatter

        init(referenceDate: Date) {
            self.referenceDate = referenceDate
            let df = DateFormatter()
            df.locale = Locale(identifier: "sv_SE")
            df.dateFormat = "dd/MM"
            self.dateFormatter = df
        }

        func stringForValue(_ value: Double, axis: AxisBase?) -> String {
            // value = antal timmar från periodens start
            let seconds = value * 3600.0
            let date = referenceDate.addingTimeInterval(seconds)
            return dateFormatter.string(from: date)
        }
    }

}
