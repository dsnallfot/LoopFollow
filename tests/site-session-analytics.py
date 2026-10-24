#!/usr/bin/env python3
"""Run production site matching, persistence, insulin and sensor statistics without UIKit."""
from pathlib import Path
import subprocess
import tempfile

repo = Path(__file__).resolve().parents[1]
def read(path): return (repo / path).read_text()
def section(path, start, end):
    text = read(path)
    begin = text.index(start)
    return text[begin:text.index(end, begin)]

models = section('LoopFollow/Storage/Storage.swift', 'struct SensorStartHistoryEntry:', 'struct AlarmHistoryEntry:')
json_models = section('LoopFollow/Controllers/NightscoutCache.swift', 'struct SGVJSON:', '// MARK: - Disk cache helper')
stubs = r'''
import Foundation
struct LogManager {
    static let shared = LogManager()
    enum Category { case bluetooth }
    func log(category: Category, message: String) {}
}
struct NightscoutUtils {
    static func parseISODate(_ raw: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: raw) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: raw)
    }
    static func parseDate(_ raw: String) -> Date? { parseISODate(raw) }
}
class Storage {
    static let shared = Storage()
    var pumpChangeHistory: [PumpChangeHistoryEntry] = []
    var sensorStartNotes: [SensorStartHistoryEntry] = []
    var dexcomSensorErrorOutagesCache: [DexcomSensorErrorOutageCacheItem] = []
    var dexcomSensorErrorOutagesRefreshedAt: Date?
    var suspectedCompressionLowHistory = SuspectedCompressionLowHistory()
}
struct NightscoutCache {
    static var retentionDays = 91
    static var treatmentSearchRevision = 0
    static var payloads: [Date: DayPayload] = [:]
    static var dayReads = 0
    static func readTreatmentsForSearch(_ day: Date) throws -> [TreatmentJSON] {
        guard let payload = payloads[day] else { throw CocoaError(.fileNoSuchFile) }
        return payload.treatments
    }
    static func readDay(_ day: Date) throws -> DayPayload {
        dayReads += 1
        guard let payload = payloads[day] else { throw CocoaError(.fileNoSuchFile) }
        return payload
    }
}
class StatsCacheManager {
    static let shared = StatsCacheManager()
    var data: SiteInsulinData?
    func siteInsulinData() -> SiteInsulinData? { data }
}
'''
checks = r'''
func approx(_ actual: Double?, _ expected: Double, _ message: String = "") {
    precondition(actual != nil && abs(actual! - expected) < 0.001, "\(message): \(String(describing: actual)) != \(expected)")
}
func note(_ id: String, _ time: Double, _ value: String, type: String = "Note") -> TreatmentJSON {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return TreatmentJSON(dict: ["_id": id, "created_at": formatter.string(from: Date(timeIntervalSince1970: time)),
                                "eventType": type, "notes": value])!
}
@main struct Checks {
    static func main() async throws {
        // Backward-compatible storage and new metadata round trips.
        var pump = try JSONDecoder().decode(PumpChangeHistoryEntry.self, from: Data(#"{"date":3600}"#.utf8))
        var sensor = try JSONDecoder().decode(SensorStartHistoryEntry.self, from: Data(#"{"date":3600,"note":"old"}"#.utf8))
        precondition(pump.site == nil && pump.tdd == nil && sensor.site == nil && sensor.siteErrorSummary == nil)
        pump.site = HealthLogSite.rightThigh.rawValue
        pump.siteIsManual = true
        pump.insulinSummary = SiteSessionMetric(start: 3600, end: 90000, total: 20, sourceDigest: "fixture")
        let roundTrip = try JSONDecoder().decode(PumpChangeHistoryEntry.self, from: JSONEncoder().encode(pump))
        precondition(roundTrip == pump)
        approx(roundTrip.tdd, 20)
        sensor.site = HealthLogSite.leftUpperArm.rawValue
        sensor.siteIsManual = true
        let sensorTrip = try JSONDecoder().decode(SensorStartHistoryEntry.self, from: JSONEncoder().encode(sensor))
        precondition(sensorTrip.site == sensor.site && sensorTrip.siteIsManual == true)

        // Counts use saved session attributes, including manual and archived sites, not source notes.
        var automatic = PumpChangeHistoryEntry(date: 7200)
        automatic.site = "Mage (Höger)"
        automatic.siteNoteID = "source-note"
        var manualWithNote = pump
        manualWithNote.siteNoteID = "another-source-note"
        var unset = PumpChangeHistoryEntry(date: 10800)
        unset.siteIsManual = true
        var unknownSitePump = PumpChangeHistoryEntry(date: 14400)
        unknownSitePump.site = "Unknown site"
        var sameTimestampSensor = sensor
        sameTimestampSensor.date = pump.date
        let countedPumps = [manualWithNote, automatic, automatic, unset, unknownSitePump]
        let countedSensors = [sameTimestampSensor, sameTimestampSensor, SensorStartHistoryEntry(date: 20000, note: "no site")]
        let allSites = SiteHistorySummary(pumps: countedPumps, sensors: countedSensors, filter: .all)
        precondition(allSites.entries.count == 3 && allSites.pumpCount == 2 && allSites.sensorCount == 1)
        precondition(allSites.count(at: .rightThigh) == 1 && allSites.count(at: .rightAbdomen) == 1 && allSites.count(at: .leftUpperArm) == 1)
        let pumpSites = SiteHistorySummary(pumps: countedPumps, sensors: countedSensors, filter: .pump)
        precondition(pumpSites.entries.count == 2 && pumpSites.sensorCount == 0)
        let sensorSites = SiteHistorySummary(pumps: countedPumps, sensors: countedSensors, filter: .sensor)
        precondition(sensorSites.entries.count == 1 && sensorSites.pumpCount == 0)
        precondition(SiteHistorySummary(pumps: [unset], sensors: [], filter: .all).entries.isEmpty)

        // Every site and kind, malformed notes, and timestamp association including an exact boundary.
        for site in HealthLogSite.allCases {
            for (prefix, kind) in [("Pumpsite", SiteHistoryFilter.pump), ("Sensorsite", .sensor)] {
                let entry = SiteHistoryEntry(id: "n", date: Date(), eventType: "Note", notes: "\(prefix): \(site.rawValue)")!
                precondition(entry.kind == kind && entry.site == site)
            }
        }
        precondition(SiteHistoryEntry(id: "bad", date: Date(), eventType: "Note", notes: "Pumpsite: Hand") == nil)
        let records = [note("before", 9, "Pumpsite: Lår (Höger)"), note("old", 11, "Pumpsite: Mage (Höger)"),
                       note("new", 20, "Pumpsite: Lår (Vänster)"), note("sensor", 21, "Sensorsite: Överarm (Höger)")]
        let entries = records.compactMap { SiteHistoryEntry(id: $0._id, date: $0.created_at, eventType: $0.eventType, notes: $0.notes) }
        let links = SiteSessionAnalytics.linkedNotes(entries, starts: [20, 10], kind: .pump)
        precondition(links[10]?.id == "old" && links[20]?.id == "new" && links.count == 2)

        // Exact partial-day clipping, no dose double counting at next pump start, and SMB+bolus totals.
        let t0 = 3600.0, t1 = t0 + 12 * 3600
        var data = SiteInsulinData(basal: [.init(date: 0, value: 1), .init(date: t1, value: 1)],
            bolus: [.init(date: t0 - 1, value: 100), .init(date: t0, value: 2), .init(date: t0 + 1, value: 1), .init(date: t1, value: 100)],
            availableDays: [0], updatedAt: Date(timeIntervalSince1970: t1))
        let metric = SiteSessionAnalytics.insulin(start: t0, end: t1, data: data, previous: nil)!
        approx(metric.total, 15, "partial first day")
        approx(metric.dailyAverage, 30)
        precondition(SiteSessionAnalytics.insulin(start: t0, end: t1, data: data, previous: metric) == metric)
        data.bolus.append(.init(date: t0 + 2, value: 3))
        let corrected = SiteSessionAnalytics.insulin(start: t0, end: t1, data: data, previous: metric)!
        approx(corrected.total, 18, "late dose invalidates cache")
        precondition(corrected.sourceDigest != metric.sourceDigest)
        data.availableDays = []
        precondition(SiteSessionAnalytics.insulin(start: t0, end: t1, data: data, previous: metric) == nil)
        data.availableDays = [0]
        data.basal = [.init(date: t0 + 60, value: 1), .init(date: t1, value: 1)]
        precondition(SiteSessionAnalytics.insulin(start: t0, end: t1, data: data, previous: nil) == nil)
        data.basal = [.init(date: 0, value: 1)]
        precondition(SiteSessionAnalytics.insulin(start: t0, end: t1, data: data, previous: nil) == nil, "stale basal cannot extend forever")
        precondition(SiteSessionAnalytics.insulin(start: t0, end: t0, data: data, previous: nil) == nil)
        approx(SiteSessionAnalytics.dailyAverage([metric, .init(start: 0, end: 86400, total: 15, sourceDigest: "x")]), 20, "duration weighted")

        // Production background worker: late site notes, manual override, structured sensor errors, reuse.
        let now = Date()
        let cal = Calendar.current
        let today = cal.startOfDay(for: now)
        let start = today.addingTimeInterval(-2 * 86400).timeIntervalSince1970
        let change = today.addingTimeInterval(-86400).timeIntervalSince1970
        let firstPump = PumpChangeHistoryEntry(date: start)
        let newPump = PumpChangeHistoryEntry(date: change)
        let firstSensor = SensorStartHistoryEntry(date: start, note: "first")
        let newSensor = SensorStartHistoryEntry(date: change, note: "second")
        NightscoutCache.payloads = [:]
        for offset in -2...0 {
            let day = cal.date(byAdding: .day, value: offset, to: today)!
            let end = cal.date(byAdding: .day, value: 1, to: day)!
            NightscoutCache.payloads[day] = DayPayload(sgv: [SGVJSON(date: day.timeIntervalSince1970, sgv: 100), SGVJSON(date: end.timeIntervalSince1970 - 1, sgv: 100)], treatments: [])
        }
        let notesDay = cal.startOfDay(for: Date(timeIntervalSince1970: start))
        NightscoutCache.payloads[notesDay]!.treatments = [note("p", start + 300, "Pumpsite: Lår (Höger)"), note("s", start + 600, "Sensorsite: Överarm (Vänster)")]
        StatsCacheManager.shared.data = SiteInsulinData(basal: [.init(date: start, value: 1), .init(date: change, value: 1), .init(date: now.timeIntervalSince1970, value: 1)], bolus: [],
            availableDays: Set((Int(floor(start / 86400))...Int(floor(now.timeIntervalSince1970 / 86400)))), updatedAt: now)
        let outage = DexcomSensorErrorOutageCacheItem(noteTimestamp: start + 3600, startTimestamp: start + 3600,
            endTimestamp: start + 7200, durationIsKnown: true, calculationVersion: 3)
        let worker = SiteSessionWorker()
        let first = await worker.refresh(pumps: [firstPump, newPump], sensors: [firstSensor, newSensor], outages: [outage], outagesRefreshedAt: now, now: now)
        precondition(first.pumps[0].site == "Lår (Höger)" && first.sensors[0].site == "Överarm (Vänster)")
        approx(first.pumps[0].tdd, 24)
        approx(first.sensors[0].siteErrorSummary?.dailyAverage, 60)
        precondition(first.currentPumpMetric != nil && first.pumps[1].insulinSummary == nil)
        NightscoutCache.dayReads = 0
        let second = await worker.refresh(pumps: first.pumps, sensors: first.sensors, outages: [outage], outagesRefreshedAt: now, now: now)
        precondition(second.pumps[0].insulinSummary == first.pumps[0].insulinSummary)
        precondition(NightscoutCache.dayReads == 0, "unchanged summaries must not re-read raw glucose")
        var manual = first.pumps
        manual[0].site = nil; manual[0].siteIsManual = true
        let overridden = await worker.refresh(pumps: manual, sensors: first.sensors, outages: [outage], outagesRefreshedAt: now, now: now)
        precondition(overridden.pumps[0].site == nil, "manual none must survive automatic linking")
        NightscoutCache.payloads[notesDay]!.treatments = []
        NightscoutCache.treatmentSearchRevision += 1
        let deleted = await worker.refresh(pumps: first.pumps, sensors: first.sensors, outages: [outage], outagesRefreshedAt: now, now: now)
        precondition(deleted.pumps[0].site == nil && deleted.sensors[0].site == nil, "deleted note must unlink")
        var unknown = outage
        unknown.durationIsKnown = false
        let incomplete = await worker.refresh(pumps: first.pumps, sensors: first.sensors, outages: [unknown], outagesRefreshedAt: now, now: now)
        precondition(incomplete.sensors[0].siteErrorSummary == nil, "unknown duration is not zero")
        let noErrors = await worker.refresh(pumps: [], sensors: first.sensors, outages: [], outagesRefreshedAt: now, now: now)
        approx(noErrors.sensors[0].siteErrorSummary?.total, 0, "verified no errors is zero")
        NightscoutCache.payloads.removeValue(forKey: notesDay)
        let noCoverageWorker = SiteSessionWorker()
        let missing = await noCoverageWorker.refresh(pumps: [], sensors: [firstSensor, newSensor], outages: [], outagesRefreshedAt: now, now: now)
        precondition(missing.sensors[0].siteErrorSummary == nil, "missing source cannot become zero sensor errors")
        // Changing session boundaries invalidates cached TDD and sensor statistics.
        var changedPumps = first.pumps
        changedPumps[1].date += 3600
        let shifted = await worker.refresh(pumps: changedPumps, sensors: first.sensors, outages: [outage], outagesRefreshedAt: now, now: now)
        precondition(shifted.pumps[0].insulinSummary?.end == change + 3600)
        let archiveDate = start - 100 * 86400
        var archive = PumpChangeHistoryEntry(date: archiveDate)
        archive.site = "Mage (Höger)"; archive.siteNoteID = "archived"; archive.siteNoteDate = archiveDate + 60
        archive.insulinSummary = SiteSessionMetric(start: archiveDate, end: start, total: 120, sourceDigest: "archived")
        let archived = await worker.refresh(pumps: [archive, firstPump], sensors: [], outages: [], outagesRefreshedAt: now, now: now)
        precondition(archived.pumps[0].site == archive.site && archived.pumps[0].insulinSummary == archive.insulinSummary)
        let stats = SiteSessionStatistics(pumps: first.pumps, sensors: first.sensors, currentPumpMetric: first.currentPumpMetric, now: now)
        approx(stats.pumpDurationHours(site: nil), 24)
        approx(stats.sensorDurationDays(site: .leftUpperArm), 1)
        precondition(stats.pumpMetrics(site: .leftThigh).isEmpty)
        approx(SiteSessionAnalytics.dailyAverage(stats.sensorMetrics(site: .leftUpperArm)), 60)
        // Persistent compression-low observations: same reading/restart, episode grouping, recovery,
        // sensor boundaries, late metadata, zero vs missing history, and site averages.
        var compression = SuspectedCompressionLowHistory()
        var observedSensors = [SensorStartHistoryEntry(date: 0, note: "old"), SensorStartHistoryEntry(date: 4000, note: "new")]
        observedSensors[0].site = "Lår (Höger)"
        observedSensors[1].site = "Överarm (Vänster)"
        precondition(compression.observe(timestamp: 1000, suspected: true, recovered: false, now: 1000, sensors: &observedSensors))
        precondition(!compression.observe(timestamp: 1000, suspected: true, recovered: false, now: 1001, sensors: &observedSensors))
        compression = try JSONDecoder().decode(SuspectedCompressionLowHistory.self, from: JSONEncoder().encode(compression))
        precondition(!compression.observe(timestamp: 1000, suspected: true, recovered: false, now: 1001, sensors: &observedSensors))
        precondition(compression.observe(timestamp: 1300, suspected: true, recovered: false, now: 1300, sensors: &observedSensors))
        precondition(compression.events.count == 1 && observedSensors[0].suspectedCompressionLows == [1000])
        precondition(compression.observe(timestamp: 1600, suspected: false, recovered: true, now: 1600, sensors: &observedSensors))
        precondition(compression.observe(timestamp: 1900, suspected: true, recovered: false, now: 1900, sensors: &observedSensors))
        precondition(compression.events.count == 2)
        precondition(compression.observe(timestamp: 3800, suspected: true, recovered: false, now: 3800, sensors: &observedSensors))
        precondition(compression.events.count == 3, "30 minute gap starts a new episode")
        precondition(compression.observe(timestamp: 4000, suspected: true, recovered: false, now: 4000, sensors: &observedSensors))
        precondition(compression.events.count == 4 && observedSensors[1].suspectedCompressionLows == [4000], "new sensor owns exact boundary")
        precondition(!compression.observe(timestamp: 4300, suspected: true, recovered: false, now: 5000, sensors: &observedSensors))
        precondition(!compression.observe(timestamp: 6000, suspected: true, recovered: false, now: 5000, sensors: &observedSensors))
        var late = SuspectedCompressionLowHistory()
        var missingSensors: [SensorStartHistoryEntry] = []
        precondition(late.observe(timestamp: 300, suspected: true, recovered: false, now: 300, sensors: &missingSensors))
        missingSensors = late.reconciled([SensorStartHistoryEntry(date: 0, note: "late")])
        precondition(missingSensors[0].suspectedCompressionLows == [300])
        observedSensors.append(SensorStartHistoryEntry(date: 5000, note: "observed zero", site: "Överarm (Vänster)"))
        precondition(compression.observe(timestamp: 5300, suspected: false, recovered: true, now: 5300, sensors: &observedSensors))
        precondition(observedSensors[2].suspectedCompressionLows == [])
        observedSensors.append(SensorStartHistoryEntry(date: -5000, note: "legacy"))
        let compressionStats = SiteSessionStatistics(pumps: [], sensors: observedSensors, currentPumpMetric: nil, now: Date(timeIntervalSince1970: 5400))
        precondition(compressionStats.compressionLowCounts(site: nil) == [3, 1, 0])
        approx(SiteSessionAnalytics.mean(compressionStats.compressionLowCounts(site: .leftUpperArm).map(Double.init)), 0.5)
        precondition(compressionStats.compressionLowCounts(site: .rightAbdomen).isEmpty)
        let imported = compression.reconciled(observedSensors)
        precondition(imported[0].suspectedCompressionLows == [1000, 1900, 3800], "timestamp union prevents double counts")
        observedSensors[1].trioSentAt = Date(timeIntervalSince1970: 3900)
        let repaired = compression.reconciled(observedSensors)
        precondition(repaired[1].suspectedCompressionLows == [4000])
        let legacySensor = try JSONDecoder().decode(SensorStartHistoryEntry.self, from: Data(#"{"date":0,"note":"legacy"}"#.utf8))
        precondition(legacySensor.suspectedCompressionLows == nil)
        let persistedSensor = try JSONDecoder().decode(SensorStartHistoryEntry.self, from: JSONEncoder().encode(imported[0]))
        precondition(persistedSensor.suspectedCompressionLows == imported[0].suspectedCompressionLows)

        var legacyHistory = try JSONDecoder().decode(SuspectedCompressionLowHistory.self, from:
            Data(#"{"events":[{"timestamp":300,"lastDetectedAt":300},{"timestamp":900,"lastDetectedAt":900}],"lastReading":900,"episodeActive":true}"#.utf8))
        var legacySessions = [SensorStartHistoryEntry(date: 0, note: "legacy")]
        legacyHistory.mergeHistorical([.init(timestamp: 1200, suspected: false, recovered: true, live: false)], sensors: &legacySessions)
        precondition(legacyHistory.events.count == 2, "migration retains previously distinct episodes")
        let samples = [100, 98, 94, 70, 40, 110, 108, 104, 70].enumerated().map {
            SGVJSON(date: Double($0.offset) * 300, sgv: $0.element)
        }
        let calculated = SuspectedCompressionLowHistory.calculateSuspectedCompressionLows(samples.reversed() + samples,
            from: 900, to: 2400, lowThreshold: 75)
        precondition(calculated.filter(\.suspected).map(\.timestamp) == [900, 2400])
        precondition(SuspectedCompressionLowHistory.calculateSuspectedCompressionLows(samples,
            from: 900, to: 2400, lowThreshold: 60).filter(\.suspected).isEmpty)
        let gapped = [SGVJSON(date: 0, sgv: 100), SGVJSON(date: 300, sgv: 98),
                      SGVJSON(date: 600, sgv: 94), SGVJSON(date: 2000, sgv: 70)]
        precondition(SuspectedCompressionLowHistory.calculateSuspectedCompressionLows(gapped,
            from: 0, to: 2400, lowThreshold: 75).isEmpty, "do not infer drops over missing data")
        var backfilled = SuspectedCompressionLowHistory()
        var sessions = [SensorStartHistoryEntry(date: 0, note: "first"), SensorStartHistoryEntry(date: 2000, note: "second")]
        backfilled.mergeHistorical(calculated, sensors: &sessions)
        precondition(sessions[0].suspectedCompressionLows == [900] && sessions[1].suspectedCompressionLows == [2400])
        let firstPass = backfilled
        backfilled.mergeHistorical(calculated, sensors: &sessions)
        precondition(firstPass == backfilled, "repeat backfill is idempotent")
        precondition(backfilled.observe(timestamp: 2400, suspected: false, recovered: false, now: 2400, sensors: &sessions))
        backfilled.mergeHistorical(calculated, sensors: &sessions)
        precondition(!backfilled.hitTimestamps.contains(2400), "live IOB veto survives later backfill")
        precondition(sessions[1].suspectedCompressionLows == [], "a removed candidate cannot survive in the session attribute")
        backfilled = try JSONDecoder().decode(SuspectedCompressionLowHistory.self, from: JSONEncoder().encode(backfilled))
        precondition(backfilled.hitTimestamps == [900])
        // A newly found earlier hit merges an existing episode, without leaving its old start counted.
        var merged = SuspectedCompressionLowHistory()
        var oneSensor = [SensorStartHistoryEntry(date: 0, note: "one")]
        _ = merged.observe(timestamp: 1200, suspected: true, recovered: false, now: 1200, sensors: &oneSensor)
        merged.mergeHistorical([.init(timestamp: 900, suspected: true, recovered: false, live: false)], sensors: &oneSensor)
        precondition(merged.events.count == 1 && oneSensor[0].suspectedCompressionLows == [900])
        precondition(Set(merged.hitTimestamps) == [900, 1200], "all hit readings get markers but only one episode is counted")
        print("Site session analytics and compression-low regressions passed")
    }
}
'''
with tempfile.TemporaryDirectory(prefix='site-sessions-') as directory:
    directory = Path(directory)
    source = directory / 'checks.swift'
    source.write_text(stubs + json_models + models + read('LoopFollow/Remote/TRC/HealthLoggingRules.swift')
                      + read('LoopFollow/Views/SiteHistoryRules.swift') + read('LoopFollow/Stats/StatsHelpers/StatsBasalEngine.swift')
                      + read('LoopFollow/Views/SiteSessionAnalytics.swift')
                      + section('LoopFollow/Controllers/SuspectedCompressionLowTracker.swift', 'struct SuspectedCompressionLowHistory:', 'extension Storage')
                      + read('LoopFollow/Views/SiteSessionService.swift') + checks)
    binary = directory / 'checks'
    subprocess.run(['xcrun', 'swiftc', '-parse-as-library', '-swift-version', '5', '-module-cache-path', '/tmp/site-session-test-modules', str(source), '-o', str(binary)], check=True)
    subprocess.run([str(binary)], check=True)
