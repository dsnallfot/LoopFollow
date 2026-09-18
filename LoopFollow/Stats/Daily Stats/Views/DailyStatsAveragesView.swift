import SwiftUI
import UIKit

@available(iOS 26.0, *)
struct DailyStatsAveragesView: View {
    let averages: DailyStatsAverages
    let thresholds: DailyStatsDisplayThresholds
    let showingTitrSummary: Bool

    // MARK: - Averages Section

    var body: some View {
        // Vi baserar oss på samma scope som tabellen (rowsWithSufficientGlucose)
        let avgCarbs = averages.averageCarbs
        let avgTDD = averages.averageTDD
        let avgMean = averages.averageMeanGlucose
        let avgLow = averages.averageLowPercent
        let avgTitr = averages.averageTitr
        let avgTir = averages.averageTir
        let avgStd = averages.averageStdDev
        //let avgBasal = viewModel.averageProfileBasal

        return HStack(spacing: 0) {
            averageBadge(
                title: "KH",
                value: avgCarbs.map { String(format: "%.0f g", $0) } ?? "—",
                background: Color(UIColor.carbs).opacity(avgCarbs == nil ? 0.25 : 0.8)
            )

            Spacer(minLength: 0)

            averageBadge(
                title: "TDD",
                value: avgTDD.map { String(format: "%.1f E", $0) } ?? "—",
                background: Color(UIColor.insulin).opacity(avgTDD == nil ? 0.25 : 0.8)
            )
            
            Spacer(minLength: 0)
/*
            averageBadge(
                title: "Basal",
                value: avgBasal.map { String(format: "%.1f E", $0) } ?? "—",
                background: Color(UIColor.insulin).opacity(avgBasal == nil ? 0.25 : 0.8)
            )

            Spacer(minLength: 0)
*/
            // Medel BG
            let meanColor: Color = {
                guard let v = avgMean else { return .gray.opacity(0.4) }
                if v <= thresholds.bgAverageGreatThreshold {
                    return .green.opacity(0.8)
                } else if v <= thresholds.bgAverageOKThreshold {
                    return .orange.opacity(0.8)
                } else {
                    return .red.opacity(0.8)
                }
            }()
            averageBadge(
                title: "MEDEL",
                value: avgMean.map { String(format: "%.1f", $0) } ?? "—",
                background: meanColor
            )

            Spacer(minLength: 0)

            // Låg %
            let lowColor: Color = {
                guard let p = avgLow else { return .gray.opacity(0.4) }
                let fraction = (p / 100.0)
                if fraction <= thresholds.lowGlucoseGreatThreshold {
                    return .green.opacity(0.8)
                } else if fraction <= thresholds.lowGlucoseOKThreshold {
                    return .orange.opacity(0.8)
                } else {
                    return .red.opacity(0.8)
                }
            }()

            // TITR / TIR (beroende på showingTitrSummary)
            let titrText = avgTitr.map { String(format: "%.0f %%", $0) } ?? "—"
            let tirText = avgTir.map { String(format: "%.0f %%", $0) } ?? "—"
            let combinedText = showingTitrSummary ? titrText : tirText
            let titrTirColor: Color = {
                if showingTitrSummary {
                    guard let p = avgTitr else { return .gray.opacity(0.4) }
                    let fraction = p / 100.0
                    return fraction >= thresholds.titrTargetThreshold ? .green.opacity(0.8) : .red.opacity(0.8)
                } else {
                    guard let p = avgTir else { return .gray.opacity(0.4) }
                    let fraction = p / 100.0
                    return fraction >= thresholds.tirTargetThreshold ? .green.opacity(0.8) : .red.opacity(0.8)
                }
            }()
            
            averageBadge(
                title: "LÅG",
                value: avgLow.map { String(format: "%.1f %%", $0) } ?? "—",
                background: lowColor
            )

            Spacer(minLength: 0)
            
            averageBadge(
                title: showingTitrSummary ? "TITR" : "TIR",
                value: combinedText,
                background: titrTirColor
            )

            Spacer(minLength: 0)

            // Std Av
            let stdColor: Color = {
                guard let s = avgStd else { return .gray.opacity(0.4) }
                if s <= thresholds.stdDevGreatThreshold {
                    return .green.opacity(0.8)
                } else if s <= thresholds.stdDevOkThreshold {
                    return .orange.opacity(0.8)
                } else {
                    return .red.opacity(0.8)
                }
            }()
            averageBadge(
                title: "STD.AV",
                value: avgStd.map { String(format: "%.1f", $0) } ?? "—",
                background: stdColor
            )
        }
        .frame(height: 35)
    }

    // MARK: - Average Badge Helper

    private func averageBadge(title: String, value: String, background: Color) -> some View {
        ZStack {
            Capsule()
                .fill(background)
            VStack(spacing: 2) {
                Text(title)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white)
                Text(value)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
            }
            .padding(.horizontal, 2)
        }
        .frame(width: 56, height: 35) // utan basal-pill
        //.frame(width: 47, height: 32) // med basal-pill
    }

}
