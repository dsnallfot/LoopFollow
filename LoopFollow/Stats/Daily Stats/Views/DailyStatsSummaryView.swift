import SwiftUI
import UIKit

@available(iOS 26.0, *)
struct DailyStatsSummaryView: View {
    let rows: [DailyStatRow]
    let numberOfDaysInScope: Int
    let numberOfDaysMeetingTitrTarget: Int
    let numberOfDaysMeetingTirTarget: Int
    let thresholds: DailyStatsDisplayThresholds
    @Binding var showingTitrSummary: Bool

    var body: some View {
        let daysInScope = numberOfDaysInScope
        let daysMeetingTitr = numberOfDaysMeetingTitrTarget
        let daysMeetingTir = numberOfDaysMeetingTirTarget
        let titrThresholdPercentString = String(format: "%.0f%%", thresholds.titrTargetThreshold * 100)
        let tirThresholdPercentString = String(format: "%.0f%%", thresholds.tirTargetThreshold * 100)
        let daysInScopeString = "\(daysInScope)"
        let daysMeetingTitrString = "\(daysMeetingTitr)"
        let daysMeetingTirString = "\(daysMeetingTir)"

        return Group {
            if daysInScope > 0 {
                VStack(alignment: .leading, spacing: 6) {
                    Group {
                        VStack(alignment: .leading, spacing: 4) {
                            // Rad 1: “Du nådde ditt mål på XX% tid i ...”
                            HStack(spacing: 0) {
                                Text("Du nådde målet ")
                                Text(showingTitrSummary ? titrThresholdPercentString : tirThresholdPercentString)
                                    .fontWeight(.bold)
                                    .foregroundColor(Color.green.opacity(0.8))
                                Text(showingTitrSummary ? " tid i tight målområde" : " tid i målområde ")
                                Spacer(minLength: 0)

                                Image(systemName: "chevron.up.chevron.down")
                                    .foregroundColor(.secondary)
                            }

                            // Rad 2: intervallet i grått
                            HStack(spacing: 0) {
                            Text(showingTitrSummary ? "(3.9–7.8 mmol/L) " : "(3.9–10.0 mmol/L) ")
                                .foregroundColor(.secondary)
                                Text("under ")
                                Text(showingTitrSummary ? daysMeetingTitrString : daysMeetingTirString)
                                    .fontWeight(.bold)
                                Text(" av ")
                                Text(daysInScopeString)
                                    .fontWeight(.bold)
                                Text(" dagar.")
                            }
                        }
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 2)

                    if showingTitrSummary {
                        titrStreakBar
                    } else {
                        tirStreakBar
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showingTitrSummary.toggle()
                    }
                }
            } else {
                Text("Ingen daglig statistik att visa ännu.")
            }
        }
        .font(.system(size: 14))
        .multilineTextAlignment(.leading)
    }

    /// Visar en enkel streak/gap-rad där varje dag i perioden representeras av en stapel.
    /// Grön = dag når TITR-målet, transparent = dag under målet.
    /// Endast dagar där vi har TITR-data (tightRangePercent != nil) ritas ut.
    private var titrStreakBar: some View {
        // Sortera dagar i kronologisk ordning (äldst till nyast) för vänster-till-höger-läsning
        // och filtrera bort dagar utan TITR-data.
        let filteredRows = rows
            .sorted { $0.date < $1.date }
            .filter { $0.tightRangePercent != nil }

        let barHeight: CGFloat = 15
        let barSpacing: CGFloat = 1

        return GeometryReader { geometry in
            let count = max(filteredRows.count, 1)
            let totalSpacing = barSpacing * CGFloat(max(count - 1, 0))
            let barWidth = max((geometry.size.width - totalSpacing) / CGFloat(count), 2)

            HStack(spacing: barSpacing) {
                ForEach(Array(filteredRows.enumerated()), id: \.offset) { _, row in
                    let meetsTarget = ((row.tightRangePercent ?? 0) / 100.0) >= thresholds.titrTargetThreshold

                    Rectangle()
                        .fill(meetsTarget ? Color.green.opacity(0.8) : Color.red.opacity(0.7))
                        .frame(width: barWidth, height: barHeight)
                        .overlay(
                            Rectangle()
                                .stroke(Color.green.opacity(0.2), lineWidth: 0.5)
                        )
                }
            }
        }
        .frame(height: barHeight)
    }
    
    private var tirStreakBar: some View {
        // Sortera dagar i kronologisk ordning (äldst till nyast) för vänster-till-höger-läsning
        // och filtrera bort dagar utan TITR-data.
        let filteredRows = rows
            .sorted { $0.date < $1.date }
            .filter { $0.timeInRangePercent != nil }

        let barHeight: CGFloat = 15
        let barSpacing: CGFloat = 1

        return GeometryReader { geometry in
            let count = max(filteredRows.count, 1)
            let totalSpacing = barSpacing * CGFloat(max(count - 1, 0))
            let barWidth = max((geometry.size.width - totalSpacing) / CGFloat(count), 2)

            HStack(spacing: barSpacing) {
                ForEach(Array(filteredRows.enumerated()), id: \.offset) { _, row in
                    let meetsTarget = ((row.timeInRangePercent ?? 0) / 100.0) >= thresholds.tirTargetThreshold

                    Rectangle()
                        .fill(meetsTarget ? Color.green.opacity(0.8) : Color.red.opacity(0.7))
                        .frame(width: barWidth, height: barHeight)
                        .overlay(
                            Rectangle()
                                .stroke(Color.green.opacity(0.2), lineWidth: 0.5)
                        )
                }
            }
        }
        .frame(height: barHeight)
    }
}
