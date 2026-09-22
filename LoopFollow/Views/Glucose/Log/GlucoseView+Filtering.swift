import UIKit
import Charts

extension GlucoseView {
    func isSuspectedCompressionLow(entry: Reading) -> Bool {
        let compressionLowDropMultiplier: Double = 2.0

        // Only show compression-drops if they are below target
        let targetMmol = Double(UserDefaultsRepository.targetLine.value) * GlucoseConversion.mgDlToMmolL
        guard entry.mmol <= targetMmol else { return false }

        let sourceEntries: [Reading]
        switch dataMode {
        case .allValues:
            sourceEntries = allValuesDayEntries
        case .sensorErrors:
            return false
        }

        let entriesAsc = sourceEntries.sorted { $0.date < $1.date }
        guard let index = entriesAsc.firstIndex(where: { abs($0.date.timeIntervalSince(entry.date)) < 1.0 }),
              index >= 3 else {
            return false
        }

        let currentMgdl = entriesAsc[index].mmol / GlucoseConversion.mgDlToMmolL
        let previousMgdl1 = entriesAsc[index - 1].mmol / GlucoseConversion.mgDlToMmolL
        let previousMgdl2 = entriesAsc[index - 2].mmol / GlucoseConversion.mgDlToMmolL
        let previousMgdl3 = entriesAsc[index - 3].mmol / GlucoseConversion.mgDlToMmolL

        let lastDelta = currentMgdl - previousMgdl1
        let previousDelta1 = previousMgdl1 - previousMgdl2
        let previousDelta2 = previousMgdl2 - previousMgdl3
        let previousMaxMagnitude = max(abs(previousDelta1), abs(previousDelta2))

        // Require at least ~0.5 mmol/L drop (~9 mg/dL)
        guard abs(lastDelta) >= 9 else {
            return false
        }

        return lastDelta < 0
            && previousMaxMagnitude > 0
            && abs(lastDelta) >= previousMaxMagnitude * compressionLowDropMultiplier
    }

    /// Determines which rows are shown when the filter button (line.3.horizontal.decrease.circle) is enabled.
    /// Includes:
    /// - all missing rows and delayed readings
    /// - glucose rows that are "special" (🦄, 👐, 🎯, 🆘, ⚠️)
    private func shouldIncludeWhenFiltered(_ row: GlucoseRow) -> Bool {
        switch row {
        case .missing:
            // Always keep missing rows
            return true

        case .glucose(let entry):
            if entry.delayedReading { return true }
            let targetMgdl = Double(UserDefaultsRepository.targetLine.value)
            let targetMmolRaw = targetMgdl * GlucoseConversion.mgDlToMmolL

            // Avrunda target till 1 decimal
            let targetMmol = (targetMmolRaw * 10).rounded() / 10

            // 🦄 Unicorn = exactly 5.5 mmol/L (≈ 100 mg/dL)
            if abs(entry.mmol - 5.5) < 0.02 { return true }
            // 👐 hands = exactly 6.7 mmol/L
            //if abs(entry.mmol - 6.7) < 0.02 { return true }
            // 🎯 target = exactly target mmol/L
            if abs(entry.mmol - targetMmol) < 0.02 { return true }
            // 🗜️ suspected compression low
            if isSuspectedCompressionLow(entry: entry) { return true }
            // 🆘 Very low marker ~2.2 mmol/L
            if abs(entry.mmol - 2.2) < 0.04 { return true }
            // ⚠️ Very high marker ~22.2 mmol/L
            if abs(entry.mmol - 22.2) < 0.04 { return true }
            return false

        case .sensorError:
            // Sensorfel-läget har egen vy och hanteras separat
            return false
        }
    }

    var filteredRows: [GlucoseRow] {
        if dataMode == .sensorErrors {
            return sensorErrorRows
        }

        let rows = dayRowsIncludingMissing
        if showOnlyMissingGlucose {
            // Visa saknade och försenade rader + "intressanta" värden (🦄, 👐, 🎯, 🆘, ⚠️)
            let hits = rows.filter { shouldIncludeWhenFiltered($0) }

            if hits.isEmpty {
                // Insert a synthetic placeholder missing row at noon
                let cal = Calendar.current
                let start = cal.startOfDay(for: selectedDate)
                let placeholderDate = cal.date(byAdding: .hour, value: 12, to: start) ?? start
                return [.missing(placeholderDate, .sensor)]
            }
            return hits
        }
        return rows
    }
}
