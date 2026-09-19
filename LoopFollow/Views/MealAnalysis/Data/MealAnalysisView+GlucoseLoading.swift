import UIKit

extension MealAnalysisView {
    /// Fetch BG data for the current window.
    /// - If fönstret överlappar de senaste 24 timmarna använder vi befintlig 24h‑fetchen för “live” data.
    /// - Oavsett, komplettera med BG‑värden från NightscoutCache så att äldre måltider får kurvor.
    func fetchBGData() {
        let now = Date()
        let dayAgo = now.addingTimeInterval(-24 * 60 * 60)

        // Behåll befintligt beteende för “nära nu” (senaste 24h)
        if endTime > dayAgo {
            fetchBG24h()
        }

        // Komplettera med BG-data från NightscoutCache för hela analysfönstret.
        loadBGFromCache()
    }

    func normalizedMergedBG(existing: [BGEntry], new: [BGEntry]) -> [BGEntry] {
        let cal = Calendar.current
        var merged: [TimeInterval: BGEntry] = [:]

        for e in existing {
            merged[e.date.timeIntervalSince1970] = e
        }
        for e in new {
            merged[e.date.timeIntervalSince1970] = e
        }

        // Sort
        let sorted = merged.values.sorted { $0.date < $1.date }
        guard !sorted.isEmpty else { return [] }

        // Gap-fill 5‑min slots if >6min gaps
        var out: [BGEntry] = []
        out.reserveCapacity(sorted.count)

        for i in 0..<sorted.count {
            let curr = sorted[i]
            out.append(curr)

            if i < sorted.count - 1 {
                let next = sorted[i+1]
                let gap = next.date.timeIntervalSince(curr.date)
                if gap > 360 {
                    let missing = Int(floor((gap - 360)/300)) + 1
                    if missing > 0 {
                        for k in 1...missing {
                            let d = curr.date.addingTimeInterval(Double(k)*300)
                            let filler = BGEntry(date: d, mmol: curr.mmol)
                            out.append(filler)
                        }
                    }
                }
            }
        }
        return out
    }

    /// Laddar BG‑värden från NightscoutCache för det aktuella analysfönstret
    /// och merge:ar dem in i `bgEntries`. Detta gör att äldre måltider (även >10 dagar)
    /// får glukoskurva så länge de finns i 90‑dagarscachen.
    private func loadBGFromCache() {
        let windowStart = startTime
        let windowEnd   = endTime

        Task {
            let cal = Calendar.current
            // Use a ±12h buffer to avoid clipping SGVs just outside the visible window
            // (e.g. when the window starts/ends near midnight), then trim locally.
            let bufferedStart = cal.date(byAdding: .hour, value: -12, to: windowStart) ?? windowStart
            let bufferedEnd   = cal.date(byAdding: .hour, value: 12, to: windowEnd)   ?? windowEnd

            // NightscoutCache returns both sgv and treatments; here we only care about sgv.
            let (sgvPoints, _) = await NightscoutCache.loadWindow(from: bufferedStart, to: bufferedEnd)

            // Map cache points to BGEntry in mmol/L and clamp them back to [windowStart, windowEnd].
            let factor = 18.0182
            let cachedBG: [BGEntry] = sgvPoints.map { point in
                let mmol = Double(point.sgv) / factor
                return BGEntry(date: Date(timeIntervalSince1970: point.date), mmol: mmol)
            }
            .filter { $0.date >= windowStart && $0.date <= windowEnd }

            let merged = self.normalizedMergedBG(existing: self.bgEntries, new: cachedBG)

            await MainActor.run {
                self.bgEntries = merged
                self.refreshBGChart()
                self.updateBGLabels()
            }
        }
    }

    // MARK: - BG Handling
    private func fetchBG24h() {
        BGProvider.fetch { [weak self] sgv in
            guard let self = self else { return }
            // Convert mg/dL → mmol/L for new readings
            let newBG = sgv.map {
                BGEntry(date: Date(timeIntervalSince1970: $0.date),
                        mmol: Double($0.sgv) / 18.0182)
            }
            let merged = self.normalizedMergedBG(existing: self.bgEntries, new: newBG)
            self.bgEntries = merged
            
            // Update UI
            self.updateBGLabels()
            self.refreshBGChart()
        }
    }
}
