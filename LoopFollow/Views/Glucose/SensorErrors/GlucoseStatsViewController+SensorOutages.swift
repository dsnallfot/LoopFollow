import UIKit
import Charts

extension GlucoseStatsViewController {
    // MARK: - Sensorfel helpers

    /// Build sensor error outages (deduped by the [prevBG,nextBG] span) from the full window.
    func buildSensorErrorOutages(allSGV: [SGVJSON], allTreatments: [TreatmentJSON], now: Date) -> [SensorErrorOutage] {
        // BG timestamps (sorted)
        let bgTimes: [Date] = allSGV
            .map { Date(timeIntervalSince1970: $0.date) }
            .sorted()

        // Filter Dexcom Notes first
        let dexcomTreatJSON = allTreatments.filter { tjson in
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

        var outages: [SensorErrorOutage] = []
        outages.reserveCapacity(dexcomNotes.count)

        var lastSpanKey: String?

        for note in dexcomNotes {
            let prev = nearestBG(before: note.timestamp, in: bgTimes)
            let next = nearestBG(after: note.timestamp, in: bgTimes)

            let prevKey = prev?.timeIntervalSince1970 ?? -1
            let nextKey = next?.timeIntervalSince1970 ?? -1
            let spanKey = "\(prevKey)-\(nextKey)"

            if spanKey == lastSpanKey {
                continue
            }
            lastSpanKey = spanKey

            let startTime = prev ?? note.timestamp
            let endTime = next ?? now
            let minutes = max(0, Int(round(endTime.timeIntervalSince(startTime) / 60.0)))

            outages.append(SensorErrorOutage(noteDate: note.timestamp, durationMinutes: minutes))
        }

        return outages.sorted { $0.noteDate > $1.noteDate }
    }

    private func nearestBG(before date: Date, in bgTimes: [Date]) -> Date? {
        guard !bgTimes.isEmpty else { return nil }
        var lo = 0
        var hi = bgTimes.count - 1
        var result: Date?
        while lo <= hi {
            let mid = (lo + hi) / 2
            let d = bgTimes[mid]
            if d < date {
                result = d
                lo = mid + 1
            } else {
                hi = mid - 1
            }
        }
        return result
    }

    private func nearestBG(after date: Date, in bgTimes: [Date]) -> Date? {
        guard !bgTimes.isEmpty else { return nil }
        var lo = 0
        var hi = bgTimes.count - 1
        var result: Date?
        while lo <= hi {
            let mid = (lo + hi) / 2
            let d = bgTimes[mid]
            if d > date {
                result = d
                hi = mid - 1
            } else {
                lo = mid + 1
            }
        }
        return result
    }
}
