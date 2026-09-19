import UIKit
import Charts

extension BGCheckView {
    /// Hämtar alla BG Check-treatments från cachen och mappar till BGCheckEntry.
    func loadBGChecks() {
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

            // Bygg CGM‑punkter (i mmol/L) från SGV‑datan
            let bgPoints: [BGPoint] = sgvs
                .map { sgv in
                    BGPoint(
                        date: Date(timeIntervalSince1970: sgv.date),
                        mmol: Double(sgv.sgv) / 18.0182
                    )
                }
                .sorted { $0.date < $1.date }

            // 1) Plocka ut alla "dextro-treatments":
            //    • eventType == "Carb Correction"
            //    • carbs > 0
            //    • notes innehåller minst en "🍬"
            let dextroTreatments: [TreatmentJSON] = treatments.filter { t in
                guard t.eventType == "Carb Correction" else { return false }
                guard let carbs = t.carbs, carbs > 0 else { return false }
                guard let notes = t.notes, notes.contains("🍬") else { return false }
                return true
            }

            let windowSeconds: TimeInterval = 10 * 60 // ±10 min

            // 2) Bygg BGCheckEntry och sätt hasDextroNearby om vi hittar en dextro inom ±10 min
            let bgChecks: [BGCheckEntry] = treatments.compactMap { (t) -> BGCheckEntry? in
                guard t.eventType == "BG Check" else { return nil }

                // Datum – använd createdAt (från created_at) om möjligt, annars date
                let date = t.created_at

                guard let raw = t.glucose else {
                    return nil
                }

                let mmol: Double
                if let units = t.units, units.lowercased().contains("mmol") {
                    mmol = raw
                } else {
                    // mg/dL -> mmol/L
                    mmol = raw / 18.0182
                }

                // Finns det en dextro-treatment inom ±10 minuter?
                let hasDextroNearby = dextroTreatments.contains { dextro in
                    abs(dextro.created_at.timeIntervalSince(date)) <= windowSeconds
                }

                // Hitta CGM‑värdet som ligger närmast 10 minuter efter fingersticket
                let target = date.addingTimeInterval(10 * 60)
                let cgmPoint = nearestBGPoint(around: target, in: bgPoints)
                let cgm10 = cgmPoint?.mmol
                let delta10 = cgm10.map { $0 - mmol }

                return BGCheckEntry(
                    date: date,
                    mmol: mmol,
                    hasDextroNearby: hasDextroNearby,
                    cgm10mMmol: cgm10,
                    delta10m: delta10
                )
            }
            .sorted { $0.date > $1.date } // nyast överst

            await MainActor.run {
                self.entries = bgChecks
                self.tableView.reloadData()
                self.updateDatePickerBounds()
                self.hideActivity()
            }
        }
    }

    // Hittar närmaste CGM‑punkt tidsmässigt runt ett givet mål.
    private func nearestBGPoint(around target: Date, in points: [BGPoint]) -> BGPoint? {
        guard !points.isEmpty else { return nil }
        // Binärsökning på tid (points är sorterade på date)
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
