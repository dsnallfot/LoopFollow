import UIKit
import Charts

extension GlucoseView {
    // MARK: - Loading

    /// Deduplicate BG entries within time buckets of the given size (in seconds).
    /// If multiple readings fall into the same bucket, keep the newest one.
    private func dedupeToBuckets(_ entries: [Reading], bucketSeconds: TimeInterval) -> [Reading] {
        var byBucket: [Int: Reading] = [:]

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

    /// Load the combined glucose history, enriching it with Nightscout upload times.
    /// Refresh today's Nightscout entries before classifying delays.
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
            // --- All-values dataset (Dex+NS merged cache) ---
            let (allSGV, _) = await NightscoutCache.loadWindow(from: bufferedStart, to: bufferedEnd)
            let allRaw = SGVJSON.includingUploadTimes(allSGV, from: nsOnlySGV)
                .map { Reading($0) }
                .filter { $0.date >= start && $0.date < endOfDay }
            let allDay = self.dedupeToBuckets(allRaw, bucketSeconds: 240.0)

            await MainActor.run {
                self.nsOnlyDayEntries = self.dedupeToBuckets(
                    nsOnlySGV.map { Reading($0) }.filter { $0.date >= start && $0.date < endOfDay },
                    bucketSeconds: 300)
                self.allValuesDayEntries = allDay

                // Aktiva värden till tabellen utifrån valt läge.
                switch self.dataMode {
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
