import UIKit
import Charts

extension GlucoseView {
    /// Returns the [start,end] bounds for a sensor outage around a missing timestamp.
    /// - start: timestamp of the last successful BG before `date` (if any)
    /// - end: timestamp of the first successful BG after `date` (if any), otherwise end-of-day/today.
    func sensorOutageBounds(around date: Date) -> (start: Date?, end: Date) {
        let cal = Calendar.current

        // Combine both datasets so we can find the nearest successful BG regardless of current mode.
        let combined = (allValuesDayEntries + nsOnlyDayEntries)
            .sorted { $0.date < $1.date }

        // Last successful BG before the missing timestamp
        let prev = combined.last(where: { $0.date < date })?.date

        // First successful BG after the missing timestamp
        let next = combined.first(where: { $0.date > date })?.date

        // If the outage has already recovered, clamp to the first BG after the gap.
        if let next = next {
            return (start: prev, end: next)
        }

        // Otherwise, the outage is ongoing (or we're looking at the tail end of the day).
        // Clamp to end-of-day for historic days, or "now" for today.
        let dayStart = cal.startOfDay(for: selectedDate)
        let endOfDay = cal.date(byAdding: .day, value: 1, to: dayStart) ?? Date.distantFuture

        if cal.isDate(selectedDate, inSameDayAs: Date()) {
            return (start: prev, end: min(Date(), endOfDay))
        } else {
            return (start: prev, end: endOfDay)
        }
    }

    /// Fetches the latest Dexcom-related Nightscout "Note" treatment after the last successful BG,
    /// and treats it as valid until a new BG arrives (end bound).
    func fetchLatestDexcomNote(after start: Date?, before end: Date) async -> Treatment? {
        // If we have no previous BG, still look back a bit to catch a note at the start of an outage.
        let fallbackLookback: TimeInterval = 6 * 3600
        let windowStart = start ?? end.addingTimeInterval(-fallbackLookback)
        let windowEnd = end

        let (_, treatsJSON) = await NightscoutCache.loadWindow(from: windowStart, to: windowEnd)

        let treatments: [Treatment] = treatsJSON.compactMap { tjson in
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

        let candidates = treatments.filter {
            $0.eventType == "Note" &&
            (($0.rawData["notes"] as? String)?
                .localizedCaseInsensitiveContains("Dexcom") ?? false) &&
            // Must be after last successful BG (if known)
            (start == nil || $0.timestamp >= start!) &&
            // And must be before recovery (or end bound)
            $0.timestamp <= end
        }

        guard !candidates.isEmpty else { return nil }

        // Latest note wins (persists across multiple missing 5-min slots)
        return candidates.max(by: { $0.timestamp < $1.timestamp })
    }

    /// Hämtar en "Note"-treatment inom ett tidsfönster runt en timestamp och filtrerar på Dexcom.
    /// - Returns: Den närmast matchande noteringen (i tid) om någon hittas.
    func fetchDexcomNoteTreatment(around date: Date, toleranceSeconds: TimeInterval) async -> Treatment? {
        let start = date.addingTimeInterval(-toleranceSeconds)
        let end = date.addingTimeInterval(toleranceSeconds)

        // Hämta treatments från cachefönster. (Vi behöver bara treatments.)
        let (_, treatsJSON) = await NightscoutCache.loadWindow(from: start, to: end)

        // Mappa cache-objekten till Treatment för enkel filtrering.
        let treatments: [Treatment] = treatsJSON.compactMap { tjson in
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

        let candidates = treatments.filter {
            $0.eventType == "Note" &&
            (($0.rawData["notes"] as? String)?
                .localizedCaseInsensitiveContains("Dexcom") ?? false)
        }

        guard !candidates.isEmpty else { return nil }

        // Välj den notering som är närmast den saknade tidsstämpeln.
        // (Denna används för snäva tidsfönster, t.ex. när Trio-uppladdning saknas.)
        return candidates.min(by: {
            abs($0.timestamp.timeIntervalSince(date)) < abs($1.timestamp.timeIntervalSince(date))
        })
    }
}
