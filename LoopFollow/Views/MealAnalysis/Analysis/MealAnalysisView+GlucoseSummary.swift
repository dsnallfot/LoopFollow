import UIKit

extension MealAnalysisView {
    private func nearestBG(to date: Date) -> Double? {
        return bgEntries.min { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) }?.mmol
    }
    
    func updateBGLabels() {
        let startBG = nearestBG(to: startTime)
        let endBG   = nearestBG(to: endTime)
        // format as "X.X → Y.Y mmol/L"
        let startText = startBG != nil
        ? String(format: "%.1f", startBG!)
        : "--"
        let endText = endBG != nil
        ? String(format: "%.1f", endBG!)
        : "--"

        // Statuscirkel baserat på slut-BG relativt användarens gränser (konvertera till mg/dL)
        let statusSymbol: String
        if let endBG = endBG {
            let endMgdl = endBG * 18.0182
            let lowMgdl = Double(UserDefaultsRepository.lowLine.value)
            let highMgdl = Double(UserDefaultsRepository.highLine.value)
            if endMgdl > highMgdl {
                statusSymbol = "🟣"
            } else if endMgdl < lowMgdl {
                statusSymbol = "🔴"
            } else {
                statusSymbol = "🟢"
            }
        } else {
            statusSymbol = "⚪️"
        }
        changeBGTitleLabel.text = " \(statusSymbol)  Glukosförändring under vald tid"

        changeBGValueLabel.text = "\(startText) → \(endText) mmol/L"
        // ——— NEW: compute percentages below, within, and above target ———
        let windowEntries = bgEntries.filter { $0.date >= startTime && $0.date <= endTime }
        let totalCount    = windowEntries.count
        
        let lowMmol = Double(UserDefaultsRepository.lowLine.value) / 18.0182
        let highMmol = Double(UserDefaultsRepository.highLine.value) / 18.0182
        let belowCount = windowEntries.filter { $0.mmol <  lowMmol }.count
        let inCount    = windowEntries.filter { $0.mmol >= lowMmol && $0.mmol <= highMmol }.count
        let aboveCount = windowEntries.filter { $0.mmol >  highMmol }.count
        
        let belowRange = totalCount > 0
        ? Double(belowCount) / Double(totalCount) * 100
        : 0
        let inRange = totalCount > 0
        ? Double(inCount)    / Double(totalCount) * 100
            : 0
        let aboveRange = totalCount > 0
            ? Double(aboveCount) / Double(totalCount) * 100
            : 0

        // Dynamic update of the horizontal bar labels (belowBar, inBar, aboveBar)
        // Show nothing for <1%, show number only for 2–6%, show with % for ≥6%
        if belowRange < 1 {
            belowBar.text = ""
        } else if belowRange < 6 {
            belowBar.text = String(format: "%.0f", belowRange)
        } else {
            belowBar.text = String(format: "%.0f%%", belowRange)
        }
        belowBar.isHidden = false

        if inRange < 1 {
            inBar.text = ""
        } else if inRange < 6 {
            inBar.text = String(format: "%.0f", inRange)
        } else {
            inBar.text = String(format: "%.0f%%", inRange)
        }
        inBar.isHidden = false

        if aboveRange < 1 {
            aboveBar.text = ""
        } else if aboveRange < 6 {
            aboveBar.text = String(format: "%.0f", aboveRange)
        } else {
            aboveBar.text = String(format: "%.0f%%", aboveRange)
        }
        aboveBar.isHidden = false
        // Deactivate old width constraints
        belowWidthConstraint?.isActive = false
        inWidthConstraint?.isActive = false
        aboveWidthConstraint?.isActive = false
        // Create new width constraints with updated multipliers and activate
        belowWidthConstraint = belowBar.widthAnchor.constraint(equalTo: inRangeRow.widthAnchor, multiplier: CGFloat(belowRange / 100))
        inWidthConstraint    = inBar.widthAnchor   .constraint(equalTo: inRangeRow.widthAnchor, multiplier: CGFloat(inRange / 100))
        aboveWidthConstraint = aboveBar.widthAnchor.constraint(equalTo: inRangeRow.widthAnchor, multiplier: CGFloat(aboveRange / 100))
        [belowWidthConstraint, inWidthConstraint, aboveWidthConstraint].forEach { $0?.isActive = true }

        // Redraw chart
        refreshBGChart()
    }
}
