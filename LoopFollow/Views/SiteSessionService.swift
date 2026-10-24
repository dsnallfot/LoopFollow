import Foundation

/// Serializes refreshes and merges only against the snapshot read before background work.
/// An edit/import received while computing always wins and triggers a fresh calculation.
@MainActor
final class SiteSessionService {
    static let shared = SiteSessionService()
    static let didUpdate = Notification.Name("SiteSessionsUpdated")
    private let worker = SiteSessionWorker()
    private var refreshTask: Task<Void, Never>?
    private(set) var currentPumpMetric: SiteSessionMetric?

    func refresh() async {
        if let refreshTask { await refreshTask.value; return }
        let task = Task { @MainActor in
            for _ in 0..<3 {
                let pumps = Storage.shared.pumpChangeHistory
                let sensors = Storage.shared.sensorStartNotes
                let outages = Storage.shared.dexcomSensorErrorOutagesCache
                let refreshedAt = Storage.shared.dexcomSensorErrorOutagesRefreshedAt
                let result = await worker.refresh(pumps: pumps, sensors: sensors, outages: outages,
                                                  outagesRefreshedAt: refreshedAt, now: Date())
                guard Self.same(pumps, Storage.shared.pumpChangeHistory),
                      Self.same(sensors, Storage.shared.sensorStartNotes),
                      outages == Storage.shared.dexcomSensorErrorOutagesCache,
                      refreshedAt == Storage.shared.dexcomSensorErrorOutagesRefreshedAt else { continue }
                let changed = !Self.same(pumps, result.pumps) || !Self.same(sensors, result.sensors)
                if !Self.same(pumps, result.pumps) { Storage.shared.pumpChangeHistory = result.pumps }
                if !Self.same(sensors, result.sensors) { Storage.shared.sensorStartNotes = result.sensors }
                currentPumpMetric = result.currentPumpMetric
                if changed { NotificationCenter.default.post(name: Self.didUpdate, object: nil) }
                break
            }
        }
        refreshTask = task
        await task.value
        refreshTask = nil
    }

    private static func same<T: Encodable>(_ lhs: T, _ rhs: T) -> Bool {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return (try? encoder.encode(lhs)) == (try? encoder.encode(rhs))
    }
}

private struct SiteSessionRefresh {
    var pumps: [PumpChangeHistoryEntry]
    var sensors: [SensorStartHistoryEntry]
    var currentPumpMetric: SiteSessionMetric?
}

private actor SiteSessionWorker {
    private var notes: [SiteHistoryEntry] = []
    private var readableDays = Set<Date>()
    private var notesKey = ""

    func refresh(pumps originalPumps: [PumpChangeHistoryEntry], sensors originalSensors: [SensorStartHistoryEntry],
                 outages: [DexcomSensorErrorOutageCacheItem], outagesRefreshedAt: Date?, now: Date) -> SiteSessionRefresh {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        let days = max(1, NightscoutCache.retentionDays)
        let floor = calendar.date(byAdding: .day, value: 1 - days, to: today)!
        let key = "\(today)|\(days)|\(NightscoutCache.treatmentSearchRevision)"
        if key != notesKey {
            var loaded: [SiteHistoryEntry] = []
            readableDays = []
            for offset in 0..<days {
                let day = calendar.date(byAdding: .day, value: -offset, to: today)!
                if let records = try? NightscoutCache.readTreatmentsForSearch(day) {
                    readableDays.insert(day)
                    loaded += records.compactMap {
                        guard $0.created_at >= floor, $0.created_at <= now else { return nil }
                        return SiteHistoryEntry(id: $0._id, date: $0.created_at, eventType: $0.eventType, notes: $0.notes)
                    }
                }
            }
            notes = loaded
            notesKey = key
        }
        var pumps = originalPumps
        var sensors = originalSensors
        let pumpLinks = SiteSessionAnalytics.linkedNotes(notes, starts: pumps.map(\.date), kind: .pump)
        let sensorLinks = SiteSessionAnalytics.linkedNotes(notes, starts: sensors.map(\.date), kind: .sensor)
        let insulin = StatsCacheManager.shared.siteInsulinData()
        let pumpStarts = Array(Set(pumps.map(\.date))).sorted()
        var ongoing: SiteSessionMetric?

        func canReconcile(_ timestamp: TimeInterval?) -> Bool {
            guard let timestamp else { return true }
            return readableDays.contains(calendar.startOfDay(for: Date(timeIntervalSince1970: timestamp)))
        }

        for i in pumps.indices {
            if pumps[i].siteIsManual != true {
                if let note = pumpLinks[pumps[i].date] {
                    pumps[i].site = note.site.rawValue
                    pumps[i].siteNoteID = note.id
                    pumps[i].siteNoteDate = note.date.timeIntervalSince1970
                } else if pumps[i].siteNoteID != nil && canReconcile(pumps[i].siteNoteDate) {
                    pumps[i].site = nil
                    pumps[i].siteNoteID = nil
                    pumps[i].siteNoteDate = nil
                }
            }
            let start = pumps[i].date
            guard start <= now.timeIntervalSince1970 else { pumps[i].insulinSummary = nil; continue }
            let next = pumpStarts.first { $0 > start }
            let end = min(next ?? now.timeIntervalSince1970, now.timeIntervalSince1970)
            let previous = pumps[i].insulinSummary
            if let next, next <= now.timeIntervalSince1970 {
                // Keep a verified archived summary once its source has aged out of local retention.
                if start < floor.timeIntervalSince1970,
                   let previous, previous.matches(start: start, end: end) { continue }
                pumps[i].insulinSummary = insulin.flatMap {
                    SiteSessionAnalytics.insulin(start: start, end: end, data: $0, previous: previous)
                }
            } else {
                pumps[i].insulinSummary = nil
                ongoing = insulin.flatMap {
                    SiteSessionAnalytics.insulin(start: start, end: end, data: $0, previous: nil)
                }
            }
        }

        // Read raw days only when a sensor's numeric summary needs recalculation.
        var dayPayloads: [Date: DayPayload] = [:]
        func hasCoverage(from start: TimeInterval, to end: TimeInterval) -> Bool {
            guard end > start, start >= floor.timeIntervalSince1970 else { return false }
            var day = calendar.startOfDay(for: Date(timeIntervalSince1970: start))
            while day.timeIntervalSince1970 < end {
                if dayPayloads[day] == nil { dayPayloads[day] = try? NightscoutCache.readDay(day) }
                guard let payload = dayPayloads[day], !payload.sgv.isEmpty else { return false }
                let dates = payload.sgv.filter { $0.sgv > 0 }.map { $0.readingDate.timeIntervalSince1970 }
                let nextDay = calendar.date(byAdding: .day, value: 1, to: day)!
                guard let first = dates.min(), let last = dates.max(),
                      first <= max(start, day.timeIntervalSince1970) + 600,
                      last >= min(end, nextDay.timeIntervalSince1970) - 600 else { return false }
                day = nextDay
            }
            return true
        }

        for i in sensors.indices {
            if sensors[i].siteIsManual != true {
                if let note = sensorLinks[sensors[i].date] {
                    sensors[i].site = note.site.rawValue
                    sensors[i].siteNoteID = note.id
                    sensors[i].siteNoteDate = note.date.timeIntervalSince1970
                } else if sensors[i].siteNoteID != nil && canReconcile(sensors[i].siteNoteDate) {
                    sensors[i].site = nil
                    sensors[i].siteNoteID = nil
                    sensors[i].siteNoteDate = nil
                }
            }
            let sensor = sensors[i]
            let window = sensor.sensorUsageWindow(in: sensors, now: now)
            let start = sensor.date
            let end = window.upperBound
            let isClosed = sensors.contains { $0.usageStartTimestamp > sensor.usageStartTimestamp && $0.usageStartTimestamp <= now.timeIntervalSince1970 }
            guard isClosed, end > start else { sensors[i].siteErrorSummary = nil; continue }
            let previous = sensor.siteErrorSummary
            if start < floor.timeIntervalSince1970,
               let previous, previous.matches(start: start, end: end), previous.usageStart == window.lowerBound { continue }
            let relevant = outages.filter { window.contains($0.sensorErrorTimestamp) }
            let encoder = JSONEncoder()
            encoder.outputFormatting = .sortedKeys
            let serialized = (try? encoder.encode(relevant.sorted { $0.noteTimestamp < $1.noteTimestamp })) ?? Data()
            let signature = SiteSessionAnalytics.digest("\(window.lowerBound):" + serialized.base64EncodedString())
            if let previous, previous.matches(start: start, end: end), previous.usageStart == window.lowerBound,
               previous.sourceDigest == signature { continue }
            // Unknown error lengths are not zeros. Require refreshed, full-session source coverage.
            guard let outagesRefreshedAt, outagesRefreshedAt.timeIntervalSince1970 >= end,
                  relevant.allSatisfy({ $0.durationMinutes != nil }), hasCoverage(from: start, to: end) else {
                sensors[i].siteErrorSummary = nil
                continue
            }
            let minutes = DexcomSensorErrorOutageCacheItem.mergedIntervals(relevant, from: start, to: end)
                .reduce(0) { $0 + $1.duration } / 60
            sensors[i].siteErrorSummary = SiteSessionMetric(start: start, end: end, total: minutes,
                                                           sourceDigest: signature, usageStart: window.lowerBound)
        }
        return SiteSessionRefresh(pumps: pumps, sensors: sensors, currentPumpMetric: ongoing)
    }
}
