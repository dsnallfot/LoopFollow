import UIKit
import Charts

extension GlucoseView {
    // MARK: - Loading

    /// Normalizes and merges BG entries by timestamp, removes duplicates, and sorts. No gap-fill.
    private func normalizedMergedBG(existing: [BGEntry], new: [BGEntry]) -> [BGEntry] {
        let cal = Calendar.current
        var merged: [TimeInterval: BGEntry] = [:]

        for e in existing {
            merged[e.date.timeIntervalSince1970] = e
        }
        for e in new {
            merged[e.date.timeIntervalSince1970] = e
        }

        // No gap‑fill in GlucoseView — only merge & sort
        let sorted = merged.values.sorted { $0.date < $1.date }
        return sorted
    }

    /// Deduplicate BG entries within time buckets of the given size (in seconds).
    /// If multiple readings fall into the same bucket, keep the newest one.
    private func dedupeToBuckets(_ entries: [BGEntry], bucketSeconds: TimeInterval) -> [BGEntry] {
        var byBucket: [Int: BGEntry] = [:]

        for entry in entries {
            let ts = entry.date.timeIntervalSince1970
            // Bucket window index since 1970‑01‑01
            let bucket = Int(floor(ts / bucketSeconds))

            if let existing = byBucket[bucket] {
                // Keep the newer reading within the same bucket
                if entry.date > existing.date {
                    byBucket[bucket] = entry
                }
            } else {
                byBucket[bucket] = entry
            }
        }

        return byBucket.values.sorted { $0.date < $1.date }
    }

    /// Load BG for a calendar day using both datasets, then drive the UI from the selected mode.
    /// - NS-only: Uses GlucoseNSOnlyCache (Trio → Nightscout uploads only).
    ///   For today, we first refresh the NS-only cache from Nightscout for [startOfDay, now].
    /// - All-values: Uses NightscoutCache (Dexcom+Nightscout merged BG history).
    func loadBG(for date: Date) {
        let cal = Calendar.current
        let now = Date()

        showRefreshIndicator()

        let start = cal.startOfDay(for: date)
        guard let endOfDay = cal.date(byAdding: .day, value: 1, to: start) else {
            hideRefreshIndicator()
            return
        }

        Task {
            // Expand the cache window with a ±12h buffer around the day
            let bufferedStart = cal.date(byAdding: .hour, value: -12, to: start) ?? start
            let bufferedEnd   = cal.date(byAdding: .hour, value: 12, to: endOfDay) ?? endOfDay

            // --- NS-only dataset ---
            if cal.isDate(date, inSameDayAs: now) {
                let sgvBatch = await NightscoutUtils.fetchSGVWindow(from: start, to: now)
                if !sgvBatch.isEmpty {
                    GlucoseNSOnlyCache.mergeSGVBatch(sgvBatch)
                }
            }

            let nsOnlySGV = await GlucoseNSOnlyCache.loadWindow(from: bufferedStart, to: bufferedEnd)
            let nsOnlyRaw: [BGEntry] = nsOnlySGV
                .map {
                    BGEntry(
                        date: Date(timeIntervalSince1970: $0.date),
                        mmol: Double($0.sgv) / 18.0182
                    )
                }
                .filter { $0.date >= start && $0.date < endOfDay }
            let nsOnlyDay = self.dedupeToBuckets(nsOnlyRaw, bucketSeconds: 300.0)

            // --- All-values dataset (Dex+NS merged cache) ---
            let (allSGV, _) = await NightscoutCache.loadWindow(from: bufferedStart, to: bufferedEnd)
            let allRaw: [BGEntry] = allSGV
                .map {
                    BGEntry(
                        date: Date(timeIntervalSince1970: $0.date),
                        mmol: Double($0.sgv) / 18.0182
                    )
                }
                .filter { $0.date >= start && $0.date < endOfDay }
            let allDay = self.dedupeToBuckets(allRaw, bucketSeconds: 240.0)

            await MainActor.run {
                // Cache both datasets for the selected day so that gap analysis
                // can cross-reference them when deciding missing reasons.
                self.nsOnlyDayEntries = nsOnlyDay
                self.allValuesDayEntries = allDay

                // Aktiva värden till tabellen utifrån valt läge.
                switch self.dataMode {
                case .nsOnly:
                    self.bgEntries = nsOnlyDay
                case .allValues:
                    self.bgEntries = allDay
                case .sensorErrors:
                    // Sensorfel-läget använder egen datakälla (sensorErrorRows)
                    self.bgEntries = []
                }

                self.tableView.reloadData()
                self.updateStatsLabel()
                self.hideRefreshIndicator()
            }
        }
    }
}
