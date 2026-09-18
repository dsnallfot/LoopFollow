import Foundation

struct DailyStatRow: Identifiable {
    let id = UUID()
    let date: Date

    let totalCarbs: Double?          // g
    let insulinTDD: Double?          // E (basal + bolus)
    let meanGlucoseMmol: Double?     // mmol/L
    let lowPercent: Double?          // %
    let tightRangePercent: Double?   // %
    let timeInRangePercent: Double?  // %
    let stdDevMmol: Double?          // mmol/L
    let profileBasal: Double?        // E (teoretisk profilbasal per 24h)
    let emojiDayInfo: String?           // Trailing space

    /// Antal glukosvärden för dagen (används för att filtrera bort "halva" dagar ur statistiken)
    let glucoseCount: Int?
}
