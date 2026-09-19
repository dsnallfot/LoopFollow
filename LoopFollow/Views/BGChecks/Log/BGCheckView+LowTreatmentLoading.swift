import UIKit
import Charts

extension BGCheckView {
    /// Hämtar alla Carb Correction-treatments med 🍬 i notes (lågbehandlingar) och mappar till LowTreatmentEntry.
    func loadLowTreatments() {
        showActivity()

        Task {
            let now = Date()
            let cal = Calendar.current

            // Hämta t.ex. hela cachefönstret (samma retention som övrig cache)
            let start = cal.date(
                byAdding: .day,
                value: -NightscoutCache.retentionDays,
                to: now
            ) ?? now.addingTimeInterval(-91 * 24 * 60 * 60)

            // Antag att NightscoutCache.loadWindow(from:to:) returnerar (sgv, treatments)
            let (sgvs, treatments) = await NightscoutCache.loadWindow(from: start, to: now)

            // Bygg CGM-punkter i mmol/L från SGV-datan
            let cgmPoints: [CGMPoint] = sgvs
                .map { sgv in
                    CGMPoint(
                        date: Date(timeIntervalSince1970: sgv.date),
                        mmol: Double(sgv.sgv) / 18.0182
                    )
                }
                .sorted { $0.date < $1.date }

            // Plocka ut alla BG Check-datum (för korsning mot dextro) samt mmol-värde
            var bgCheckDates: [Date] = []
            var bgCheckMmol: [Double] = []
            for t in treatments {
                guard t.eventType == "BG Check" else { continue }
                let date = t.created_at
                guard let raw = t.glucose else { continue }

                let mmol: Double
                if let units = t.units, units.lowercased().contains("mmol") {
                    mmol = raw
                } else {
                    // mg/dL -> mmol/L
                    mmol = raw / 18.0182
                }

                bgCheckDates.append(date)
                bgCheckMmol.append(mmol)
            }

            let windowSeconds: TimeInterval = 15 * 60 // ±15 min

            let lowTreatments: [LowTreatmentEntry] = treatments.compactMap { t -> LowTreatmentEntry? in
                // Endast Carb Correction med carbs > 0 och minst en 🍬 i notes
                guard t.eventType == "Carb Correction" else { return nil }
                guard let carbs = t.carbs, carbs > 0 else { return nil }
                guard let notes = t.notes, notes.contains("🍬") else { return nil }

                let date = t.created_at

                // Hitta närmaste BG Check i tid och se om den ligger inom ±15 minuter
                var nearestBGIndex: Int?
                var bestDelta = windowSeconds + 1
                for (idx, bgDate) in bgCheckDates.enumerated() {
                    let delta = abs(bgDate.timeIntervalSince(date))
                    if delta < bestDelta {
                        bestDelta = delta
                        nearestBGIndex = idx
                    }
                }

                let hasBGCheckNearby: Bool
                let bgCheckMmolNearby: Double?
                if let idx = nearestBGIndex, bestDelta <= windowSeconds {
                    hasBGCheckNearby = true
                    bgCheckMmolNearby = bgCheckMmol[idx]
                } else {
                    hasBGCheckNearby = false
                    bgCheckMmolNearby = nil
                }

                // Hitta närmaste CGM-värde vid tidpunkten för dextrobehandlingen
                let cgmPoint = nearestCGMPoint(around: date, in: cgmPoints)
                let cgmMmol = cgmPoint?.mmol

                return LowTreatmentEntry(
                    date: date,
                    grams: carbs,
                    hasBGCheckNearby: hasBGCheckNearby,
                    cgmMmol: cgmMmol,
                    bgCheckMmol: bgCheckMmolNearby
                )
            }
            .sorted { $0.date > $1.date } // nyast överst

            await MainActor.run {
                self.dextroEntries = lowTreatments
                self.dextroBGCheckDates = bgCheckDates
                self.dextroBGCheckMmol = bgCheckMmol
                self.tableView.reloadData()
                self.updateDatePickerBounds()
                // Autoscrolla till det datum som redan är valt i datePickern, nu baserat på dextro-listan
                self.datePickerChanged(self.datePicker)
                self.hideActivity()
            }
        }
    }

    // Hittar närmaste CGM-punkt tidsmässigt runt ett givet mål.
    private func nearestCGMPoint(around target: Date, in points: [CGMPoint]) -> CGMPoint? {
        guard !points.isEmpty else { return nil }

        var lo = 0
        var hi = points.count - 1
        var bestIndex = 0
        var bestDiff = abs(points[0].date.timeIntervalSince(target))

        while lo <= hi {
            let mid = (lo + hi) / 2
            let d = points[mid].date
            let diff = abs(d.timeIntervalSince(target))
            if diff < bestDiff {
                bestDiff = diff
                bestIndex = mid
            }
            if d < target {
                lo = mid + 1
            } else if d > target {
                hi = mid - 1
            } else {
                break
            }
        }
        return points[bestIndex]
    }
}
