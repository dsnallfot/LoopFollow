import SwiftUI
import UIKit

@available(iOS 16.0, *)
extension AddUserDataView {
    var heightCm: Double? {
        Double(heightText.replacingOccurrences(of: ",", with: "."))
    }

    var weightKg: Double? {
        Double(weightText.replacingOccurrences(of: ",", with: "."))
    }

    var tdd: Double? {
        Double(tddText.replacingOccurrences(of: ",", with: "."))
    }
    
    var hbA1c: Double? {
        Double(hbA1cText.replacingOccurrences(of: ",", with: "."))
    }
    
    var actualMorningCR: Double? {
        Double(actualMorningCRText.replacingOccurrences(of: ",", with: "."))
    }
    
    var actualDayCR: Double? {
        Double(actualDayCRText.replacingOccurrences(of: ",", with: "."))
    }
    
    var actualAverageISF: Double? {
        Double(actualAverageISFText.replacingOccurrences(of: ",", with: "."))
    }
    
    var actualBasal: Double? {
        Double(actualBasalText.replacingOccurrences(of: ",", with: "."))
    }

    var insulinPerKg: Double? {
        guard let tdd, let weightKg, weightKg > 0 else { return nil }
        return tdd / weightKg
    }

    var walsh500CR: Double? {
        guard let weightKg, weightKg > 0 else { return nil }
        return 500.0 / (weightKg * 0.55)
    }

    var walsh300CR: Double? {
        guard let weightKg, weightKg > 0 else { return nil }
        return 300.0 / (weightKg * 0.55)
    }

    var walshWeightCR: Double? {
        guard let weightKg, weightKg > 0 else { return nil }
        return (2.6 * weightKg / 0.45359237) / (weightKg * 0.55)
    }

    var walsh100ISF: Double? {
        guard let weightKg, weightKg > 0 else { return nil }
        return 100.0 / (weightKg * 0.55)
    }
    
    var walshTDD: Double? {
        guard let weightKg, weightKg > 0 else { return nil }
        return weightKg * 0.55
    }
    
    var walshBasal: Double? {
        guard let weightKg, weightKg > 0 else { return nil }
        return (weightKg * 0.55) * 0.48
    }
    
    var walshBasalPerHour: Double? {
        guard let weightKg, weightKg > 0 else { return nil }
        return (weightKg * 0.55) * 0.48 / 24
    }
    
    var actualBasalPerHour: Double? {
        guard let actualBasal, actualBasal > 0 else { return nil }
        return actualBasal / 24
    }
    
    // MARK: - Walsh vs actual percentage helpers
    
    /// Returnerar en sträng som "(+12 %)" eller "(-8 %)" som visar hur mycket större/mindre Walsh är jämfört med aktuellt värde.
    private func walshPercentageString(walsh: Double?, actual: Double?) -> String? {
        guard let walsh, let actual, actual != 0 else { return nil }
        let ratio = walsh / actual
        let pct = (ratio - 1.0) * 100.0
        return String(format: "(%+0.0f %%)", pct)
    }
    
    // Walsh-värden relativt aktuella inställningar
    var walshPercentageOfActual500CR: String? {
        walshPercentageString(walsh: walsh500CR, actual: actualDayCR)
    }
    
    var walshPercentageOfActual300CR: String? {
        walshPercentageString(walsh: walsh300CR, actual: actualMorningCR)
    }
    
    var walshPercentageOfActualWeightCR: String? {
        walshPercentageString(walsh: walshWeightCR, actual: actualDayCR)
    }
    
    var walshPercentageOfActualISF: String? {
        walshPercentageString(walsh: walsh100ISF, actual: actualAverageISF)
    }
    
    var walshPercentageOfActualTDD: String? {
        walshPercentageString(walsh: walshTDD, actual: tdd)
    }
    
    var walshPercentageOfActualBasal: String? {
        walshPercentageString(walsh: walshBasal, actual: actualBasal)
    }
    
    var walshPercentageOfActualBasalPerHour: String? {
        walshPercentageString(walsh: walshBasalPerHour, actual: actualBasalPerHour)
    }
}
