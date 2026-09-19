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
                let start = Date(timeIntervalSince1970: item.startTimestamp)
                let end = Date(timeIntervalSince1970: item.endTimestamp)
                let minutes = max(0, Int(round(end.timeIntervalSince(start) / 60.0)))

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

    /// Loads a 90-day list of Dexcom sensor error Notes and computes duration based on nearest BGs.
    func loadSensorErrors90Days() async {
        let cal = Calendar.current
        let now = Date()

        let hardFloor = cal.date(byAdding: .day, value: -sensorErrorLookbackDays, to: now) ?? now.addingTimeInterval(-91 * 86400)
        let overlap: TimeInterval = 6 * 3600

        // Use shared Storage cache for incremental refresh.
        let cachedItems = Storage.shared.dexcomSensorErrorOutagesCache
        let start: Date

        if cachedItems.count >= 3, let last = Storage.shared.dexcomSensorErrorOutagesRefreshedAt {
            start = max(hardFloor, last.addingTimeInterval(-overlap))
        } else {
            start = hardFloor
        }
        // Load a single wide window from the merged cache (includes Dexcom + NS values) + treatments.
        let (sgvJSON, treatsJSON) = await NightscoutCache.loadWindow(from: start, to: now)

        // Convert BG points (we only need timestamps)
        let bgTimes: [Date] = sgvJSON
            .map { Date(timeIntervalSince1970: $0.date) }
            .sorted()

        // Filter Dexcom Notes first to reduce mapping work
        let dexcomTreatJSON = treatsJSON.filter { tjson in
            tjson.eventType == "Note" && (tjson.notes?.localizedCaseInsensitiveContains("Dexcom") ?? false)
        }

        let dexcomNotes: [Treatment] = dexcomTreatJSON.compactMap { tjson in
            Treatment(dictionary: [
                "_id":       tjson._id as AnyObject,
                "eventType": tjson.eventType as AnyObject,
                "enteredBy": tjson.enteredBy as AnyObject,
                "created_at": ISO8601DateFormatter().string(from: tjson.created_at) as AnyObject,
                "rate":      tjson.rate as AnyObject,
                "absolute":  tjson.absolute as AnyObject,
                "insulin":   tjson.insulin as AnyObject,
                "carbs":     tjson.carbs as AnyObject,
                "amount":    tjson.amount as AnyObject,
                "foodType":  tjson.foodType as AnyObject,
                "notes":     tjson.notes as AnyObject,
                "glucose":   tjson.glucose as AnyObject,
                "units":     tjson.units as AnyObject,
                "duration":  tjson.tempBasalDuration as AnyObject
            ])
        }
        .sorted { $0.timestamp < $1.timestamp }

        // Build outage intervals (cache items) and dedupe multiple notes inside the same [prevBG,nextBG] span
        var outageItems: [DexcomSensorErrorOutageCacheItem] = []
        outageItems.reserveCapacity(dexcomNotes.count)

        var lastSpanKey: String?

        for note in dexcomNotes {
            let prev = nearestBG(before: note.timestamp, in: bgTimes)
            let next = nearestBG(after: note.timestamp, in: bgTimes)

            // Span key: same prev/next => same outage, only keep first
            let prevKey = prev?.timeIntervalSince1970 ?? -1
            let nextKey = next?.timeIntervalSince1970 ?? -1
            let spanKey = "\(prevKey)-\(nextKey)"

            if spanKey == lastSpanKey {
                continue
            }
            lastSpanKey = spanKey

            let startTime = prev ?? note.timestamp
            let endTime = next ?? now

            let notesText = note.rawData["notes"] as? String
            let enteredBy = note.rawData["enteredBy"] as? String

            outageItems.append(
                DexcomSensorErrorOutageCacheItem(
                    noteTimestamp: note.timestamp.timeIntervalSince1970,
                    startTimestamp: startTime.timeIntervalSince1970,
                    endTimestamp: endTime.timeIntervalSince1970,
                    notesText: notesText,
                    enteredBy: enteredBy
                )
            )
        }

        // Newest first (from the fetched window)
        let newestItems = outageItems.sorted { $0.noteTimestamp > $1.noteTimestamp }

        await MainActor.run {
            // Merge by noteTimestamp (latest computed wins), keep only within retention.
            var mergedByNote: [TimeInterval: DexcomSensorErrorOutageCacheItem] = [:]

            // Start with existing cache, drop anything older than hardFloor
            let floorTS = hardFloor.timeIntervalSince1970
            for item in cachedItems where item.noteTimestamp >= floorTS {
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
            self.statsLabel.text = "Antal sensorfel: \(merged.count) st (90d)   "
            self.hideRefreshIndicator()
        }
    }
}
