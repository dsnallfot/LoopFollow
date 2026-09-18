import SwiftUI
import UIKit

@available(iOS 26.0, *)
struct DailyStatsTableView: View {
    let rows: [DailyStatRow]
    let numberOfDaysInScope: Int
    let showingTitrSummary: Bool
    let thresholds: DailyStatsDisplayThresholds
    let dateFormatter: DateFormatter
    let onSelectDate: (Date) -> Void

    // Kolumnbredder för raka marginaler – proportionella mot skärmbredden (efter 10 pt horisontell padding)
    private let totalBaseColumnWidth: CGFloat = 356 // 26+54+36+36+36+30+30+30+32+36+10
    
    private func scaledColumnWidth(base: CGFloat) -> CGFloat {
        // Tillgänglig bredd efter 10 pt padding på vardera sida (matchar .padding(.horizontal, 10))
        let screenWidth = UIScreen.main.bounds.width
        let availableWidth = max(screenWidth - 30, 0)
        return (base / totalBaseColumnWidth) * availableWidth
    }
    
    private var weekdayWidth: CGFloat { scaledColumnWidth(base: 26) }
    private var dateWidth: CGFloat { scaledColumnWidth(base: 54) }
    private var carbsWidth: CGFloat { scaledColumnWidth(base: 35) }
    private var insulinWidth: CGFloat { scaledColumnWidth(base: 35) }
    var meanWidth: CGFloat { scaledColumnWidth(base: 36) }
    var lowWidth: CGFloat { scaledColumnWidth(base: 30) }
    var titrWidth: CGFloat { scaledColumnWidth(base: 30) }
    var tirWidth: CGFloat { scaledColumnWidth(base: 30) }
    var stdWidth: CGFloat { scaledColumnWidth(base: 32) }
    private var profileWidth: CGFloat { scaledColumnWidth(base: 35) }
    private var emojiWidth: CGFloat { scaledColumnWidth(base: 14) }
    
    private let columnSpacing: CGFloat = 1
    
    struct HighlightInfo {
        let bestID: AnyHashable?
        let worstID: AnyHashable?
    }

    var body: some View {
        // För-highlighting av bästa/sämsta dag baserat på aktuell TITR/TIR-vy
        let daysInScope = numberOfDaysInScope
        
        // Samma filtrering som tabellen använder (endast dagar med tightRangePercent)
        let filteredRowsForHighlight = rows
            .filter { $0.tightRangePercent != nil }
        
        let highlightInfo: HighlightInfo = {
            // Endast highlight om vi har fler än 1 dag (dvs 7, 14, 30, 90 – inte 1 dag)
            guard daysInScope > 1 else {
                return HighlightInfo(bestID: nil, worstID: nil)
            }
            
            // Välj rätt procent att optimera på: TITR eller TIR beroende på showingTitrSummary
            let metricRows: [(AnyHashable, Double)] = filteredRowsForHighlight.compactMap { row in
                let metric = showingTitrSummary ? row.tightRangePercent : row.timeInRangePercent
                guard let metric else { return nil }
                return (AnyHashable(row.id), metric)
            }
            
            guard metricRows.count > 1 else {
                return HighlightInfo(bestID: nil, worstID: nil)
            }
            
            let best = metricRows.max(by: { $0.1 < $1.1 })
            let worst = metricRows.min(by: { $0.1 < $1.1 })
            
            return HighlightInfo(bestID: best?.0, worstID: worst?.0)
        }()
        VStack(alignment: .leading, spacing: 0) {
            headerRow
                .padding(.vertical, 6)
            Divider()

            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(filteredRowsForHighlight.enumerated()), id: \.element.id) { index, row in
                        HStack(spacing: columnSpacing) {
                            Text(weekdaySymbol(for: row.date))
                                .frame(width: weekdayWidth, alignment: .leading)
                                .font(.system(size: 10, weight: .semibold).monospaced())
                                .foregroundColor(.secondary)

                            Text(dateFormatter.string(from: row.date))
                                .frame(width: dateWidth, alignment: .center)
                                .font(.system(size: 10).monospacedDigit())

                            numberCell(row.totalCarbs, width: carbsWidth, decimals: 0)
                            numberCell(row.insulinTDD, width: insulinWidth)
                            meanCell(row.meanGlucoseMmol)
                            lowCell(row.lowPercent)
                            titrCell(row.tightRangePercent)
                            tirCell(row.timeInRangePercent)
                            stdDevCell(stdDev: row.stdDevMmol, mean: row.meanGlucoseMmol)
                            numberCell(row.profileBasal, width: profileWidth)
                            emojiCell(row.emojiDayInfo, width: emojiWidth)
                        }
                        .padding(.vertical, 8)
                        .background({
                            // Bas: varannan rad ljusgrå
                            let baseColor: Color = index % 2 == 0
                            ? Color(.systemGray.withAlphaComponent(0.15))
                            : Color.clear

                            // Highlight: bästa / sämsta dag enligt aktuell TITR/TIR-vy
                            let isBest = highlightInfo.bestID != nil && AnyHashable(row.id) == highlightInfo.bestID
                            let isWorst = highlightInfo.worstID != nil && AnyHashable(row.id) == highlightInfo.worstID

                            if isBest {
                                return Color.green.opacity(0.25)
                            } else if isWorst {
                                return Color.red.opacity(0.25)
                            } else {
                                return baseColor
                            }
                        }())
                        .contentShape(Rectangle())
                        .onTapGesture {
                            onSelectDate(row.date)
                        }
                        Divider()
                    }
                }
            }
        }
        .padding(.horizontal, 15)
        .padding(.top, 10)

    }

    private var headerRow: some View {
        HStack(spacing: columnSpacing) {
            Text("Dag")
                .frame(width: weekdayWidth, alignment: .leading)
                .font(.system(size: 10, weight: .semibold))

            Text("Datum")
                .frame(width: dateWidth, alignment: .center)
                .font(.system(size: 10, weight: .semibold))

            Text("KH")
                .frame(width: carbsWidth, alignment: .trailing)
                .font(.system(size: 10, weight: .semibold))

            Text("TDD")
                .frame(width: insulinWidth, alignment: .trailing)
                .font(.system(size: 10, weight: .semibold))

            Text("Medel")
                .frame(width: meanWidth, alignment: .trailing)
                .font(.system(size: 10, weight: .semibold))

            Text("Låg")
                .frame(width: lowWidth, alignment: .trailing)
                .font(.system(size: 10, weight: .semibold))

            Text("TITR")
                .frame(width: titrWidth, alignment: .trailing)
                .font(.system(size: 10, weight: .semibold))
            
            Text("TIR")
                .frame(width: tirWidth, alignment: .trailing)
                .font(.system(size: 10, weight: .semibold))

            Text("StdAv")
                .frame(width: stdWidth, alignment: .trailing)
                .font(.system(size: 10, weight: .semibold))

            Text("Basal")
                .frame(width: profileWidth, alignment: .trailing)
                .font(.system(size: 10, weight: .semibold))
        }
    }

    private func weekdaySymbol(for date: Date) -> String {
        switch Calendar.current.component(.weekday, from: date) {
        case 2: return " Mån"
        case 3: return " Tis"
        case 4: return " Ons"
        case 5: return " Tor"
        case 6: return " Fre"
        case 7: return " Lör"
        default: return " Sön"
        }
    }
}
