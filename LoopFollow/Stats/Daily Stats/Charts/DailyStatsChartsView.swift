import SwiftUI
import UIKit

@available(iOS 26.0, *)
struct DailyStatsChartsView: View {
    let rows: [DailyStatRow]
    let showingTitrSummary: Bool
    @Binding var showRealCRandTitrChart: Bool

    // MARK: - Subviews

    // MARK: - Bar Chart (TDD + Carbs)

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                if showRealCRandTitrChart {
                    Text(showingTitrSummary ? "TITR" : "TIR")
                        .fontWeight(.semibold)
                        .font(.subheadline)
                        .foregroundColor(Color.green.opacity(0.85))
                    Text("och")
                        .fontWeight(.medium)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                    Text("Verklig insulinkvot")
                        .fontWeight(.semibold)
                        .font(.subheadline)
                        .foregroundColor(Color(.mint).opacity(0.9))
                    Text("per dag")
                        .fontWeight(.medium)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                } else {
                    Text("TDD")
                        .fontWeight(.semibold)
                        .font(.subheadline)
                        .foregroundColor(Color(UIColor.insulin).opacity(0.9))
                    Text("och")
                        .fontWeight(.medium)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                    Text("Kolhydrater")
                        .fontWeight(.semibold)
                        .font(.subheadline)
                        .foregroundColor(Color(UIColor.carbs).opacity(0.9))
                    Text("per dag")
                        .fontWeight(.medium)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.up.chevron.down")
                    .foregroundColor(.secondary)
                    .fontWeight(.regular)
                    .font(.system(size: 14))
            }
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showRealCRandTitrChart.toggle()
                }
            }

            if showRealCRandTitrChart {
                RealCRandTITRChartView(rows: rows, showingTitrSummary: showingTitrSummary)
                    .frame(height: 180)
                    .clipped()
            } else {
                DailyCarbsTDDBarChartView(rows: rows)
                    .frame(height: 180)
                    .clipped()
            }
        }
    }
}
