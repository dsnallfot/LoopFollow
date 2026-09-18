import SwiftUI
import UIKit

@available(iOS 26.0, *)
extension DailyStatsTableView {
    func numberCell(
        _ value: Double?,
        width: CGFloat,
        decimals: Int = 1,
        foregroundColor: Color? = nil
    ) -> some View {
        Group {
            if let value = value {
                Text(String(format: "%.\(decimals)f", value))
                    .font(.system(size: 10).monospacedDigit())
                    .foregroundColor(foregroundColor ?? .primary)
            } else {
                Text("—")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
        }
        .frame(width: width, alignment: .trailing)
    }
    
    func emojiCell(
        _ value: String?,
        width: CGFloat,
        decimals: Int = 0,
        foregroundColor: Color? = nil
    ) -> some View {
        let emoji: String = {
            guard let value else { return "" }
            let normalized = value.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)

            if normalized.contains("magsjuka") {
                return "🤢"
            }
            if normalized.contains("forkyld") {
                return "🤧"
            }

            let words = normalized
                .components(separatedBy: CharacterSet.alphanumerics.inverted)
                .filter { !$0.isEmpty }

            if words.contains("sjuk") {
                return "🤒"
            }
            return ""
        }()

        return Group {
            Text(emoji)
                .font(.system(size: 11))
        }
        .frame(width: width, alignment: .trailing)
    }

    func lowCell(_ value: Double?) -> some View {
        let color: Color
        if let value = value {
            let fraction = value / 100.0
            if fraction <= thresholds.lowGlucoseGreatThreshold {
                color = .green
            } else if fraction <= thresholds.lowGlucoseOKThreshold {
                color = .orange
            } else {
                color = .red
            }
        } else {
            color = .secondary
        }
        return numberCell(value, width: lowWidth, decimals: 1, foregroundColor: color)
    }

    func titrCell(_ value: Double?) -> some View {
        let color: Color
        //if showingTitrSummary {
            if let value = value {
                let fraction = value / 100.0
                color = fraction >= thresholds.titrTargetThreshold ? .green : .red
            } else {
                color = .secondary
            }
        //} else {
        //    color = .secondary
        //}
        return numberCell(value, width: titrWidth, decimals: 0, foregroundColor: color)
    }
    
    func tirCell(_ value: Double?) -> some View {
        let color: Color
        //if !showingTitrSummary {
        if let value = value {
            let fraction = value / 100.0
            color = fraction >= thresholds.tirTargetThreshold ? .green : .red
        } else {
            color = .secondary
        }
        //} else {
        //    color = .secondary
        //}
        return numberCell(value, width: tirWidth, decimals: 0, foregroundColor: color)
    }

    func meanCell(_ value: Double?) -> some View {
        let color: Color
        if let value = value {
            if value <= thresholds.bgAverageGreatThreshold {
                color = .green
            } else if value <= thresholds.bgAverageOKThreshold {
                color = .orange
            } else {
                color = .red
            }
        } else {
            color = .secondary
        }
        return numberCell(value, width: meanWidth, decimals: 1, foregroundColor: color)
    }

    func stdDevCell(stdDev: Double?, mean: Double?) -> some View {
        let color: Color
        if let stdDev = stdDev, stdDev > 0 {
            if stdDev <= thresholds.stdDevGreatThreshold {
                color = .green
            } else if stdDev <= thresholds.stdDevOkThreshold {
                color = .orange
            } else {
                color = .red
            }
        } else {
            color = .secondary
        }
        return numberCell(stdDev, width: stdWidth, decimals: 1, foregroundColor: color)
    }
}
