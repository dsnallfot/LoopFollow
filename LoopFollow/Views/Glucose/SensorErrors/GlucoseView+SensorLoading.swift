import UIKit
import Charts

extension GlucoseView {
    func loadSensorErrorRowsFromCache() -> [GlucoseRow] {
        // Read shared cache from Storage
        let items = Storage.shared.dexcomSensorErrorOutagesCache
        return glucoseRowsFromOutageItems(items)
    }

    private func glucoseRowsFromOutageItems(_ items: [DexcomSensorErrorOutageCacheItem]) -> [GlucoseRow] {
        // Convert shared cache items to GlucoseRow.sensorError for the table.
        return items
            .sorted { $0.noteTimestamp > $1.noteTimestamp }
            .compactMap { item in
                let noteDate = Date(timeIntervalSince1970: item.noteTimestamp)
                let minutes = item.durationMinutes

                // Create minimal Treatment so existing alert logic can reuse note.rawData["notes"/"enteredBy"].
                var raw: [String: AnyObject] = [
                    "eventType": "Note" as AnyObject,
                    "created_at": ISO8601DateFormatter().string(from: noteDate) as AnyObject
                ]
                if let notes = item.notesText {
                    raw["notes"] = notes as AnyObject
                }
                if let enteredBy = item.enteredBy {
                    raw["enteredBy"] = enteredBy as AnyObject
                }

                guard let t = Treatment(dictionary: raw) else { return nil }

                return .sensorError(
                    date: noteDate,
                    durationMinutes: minutes,
                    note: t
                )
            }
    }

    // (saveSensorErrorRowsToCache and sensorErrorLastRefreshDate removed; no longer used)

    /// Loads Dexcom sensor error Notes from the treatment cache and computes duration based on nearest BGs.
    /// Rebuild the complete local window so grouping is independent of the refresh boundary.
    func loadSensorErrors90Days() async {
        let cal = Calendar.current
        let now = Date()

        let hardFloor = cal.date(byAdding: .day, value: -sensorErrorLookbackDays, to: now) ?? now.addingTimeInterval(-91 * 86400)
        // Read the full local window so repeated notes are grouped consistently across refreshes.
        // Network backfill remains exclusive to the long-press action.
        let (sgvJSON, treatsJSON) = await NightscoutCache.loadWindow(from: hardFloor.addingTimeInterval(-60), to: now)
        let notesInWindow = treatsJSON.filter { $0.created_at >= hardFloor }
        let newestItems = DexcomSensorErrorOutageCacheItem.build(readings: sgvJSON, treatments: treatsJSON.filter { $0.eventType != "Note" || $0.created_at >= hardFloor }, now: now)
            .filter { $0.noteTimestamp >= hardFloor.timeIntervalSince1970 }
        let sourceTimestamps = Set(notesInWindow.filter { $0.eventType == "Note" }.map { $0.created_at.timeIntervalSince1970 })

        await MainActor.run {
            // Merge by noteTimestamp (latest computed wins), keep only within retention.
            var mergedByNote: [TimeInterval: DexcomSensorErrorOutageCacheItem] = [:]

            // Start with existing cache, drop anything older than hardFloor
            let floorTS = hardFloor.timeIntervalSince1970
            for item in Storage.shared.dexcomSensorErrorOutagesCache where item.noteTimestamp >= floorTS && !sourceTimestamps.contains(item.noteTimestamp) {
                mergedByNote[item.noteTimestamp] = item
            }

            // Overwrite/insert latest computed items
            for item in newestItems {
                mergedByNote[item.noteTimestamp] = item
            }

            let merged = mergedByNote.values.sorted { $0.noteTimestamp > $1.noteTimestamp }

            // Persist shared cache
            Storage.shared.dexcomSensorErrorOutagesCache = merged
            Storage.shared.dexcomSensorErrorOutagesRefreshedAt = now

            // Drive UI rows from shared cache
            self.sensorErrorRows = self.glucoseRowsFromOutageItems(merged)
            self.tableView.reloadData()

            // Stats label: count
            if self.dataMode == .sensorErrors {
                self.statsLabel.text = "Antal sensorfel: \(merged.count) st (90d)   "
            } else {
                self.updateStatsLabel()
            }
            self.hideRefreshIndicator()
        }
    }
}
