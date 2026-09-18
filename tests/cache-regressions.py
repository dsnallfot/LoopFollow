#!/usr/bin/env python3
"""Run the actual Foundation cache code against temporary files, without iOS/network.
UIKit/remote dependencies are replaced with small data-only stubs; cache algorithms
are extracted unchanged from the application sources. Requires macOS + Swift.
"""
from pathlib import Path
import subprocess
import tempfile

repo = Path(__file__).resolve().parents[1]
nightscout = (repo / 'LoopFollow/Controllers/NightscoutCache.swift').read_text()
nightscout = nightscout[nightscout.index('struct SGVJSON:'):nightscout.index('// MARK: - Battery history')]
nightscout = nightscout.replace('FileManager.default\n            .urls(for: .cachesDirectory, in: .userDomainMask)[0]', 'testRoot')
stats = (repo / 'LoopFollow/Stats/StatsHelpers/StatsDataService.swift').read_text()
stats = stats[:stats.index('\nclass StatsDataService {')]
fetcher = (repo / 'LoopFollow/Stats/StatsHelpers/StatsDataFetcher.swift').read_text()
stubs = r'''
import Foundation
let testRoot = URL(fileURLWithPath: CommandLine.arguments[1])
struct ShareGlucoseData: Codable { var sgv: Int; var date: Double; var direction: String? }
class MainViewController {
    struct bolusGraphStruct { var value: Double; var date: Double; var sgv: Int }
    struct carbGraphStruct { var value: Double; var date: Double; var sgv: Int; var absorptionTime: Int; var foodType: String?; var fat: Double; var protein: Double }
    struct basalGraphStruct { var basalRate: Double; var date: Double }
    var statsBGData: [ShareGlucoseData] = [], bgData: [ShareGlucoseData] = [], bgCheckData: [ShareGlucoseData] = []
    var statsBGCheckData: [Double] = []
    var statsBolusData: [bolusGraphStruct] = [], statsSMBData: [bolusGraphStruct] = [], bolusData: [bolusGraphStruct] = [], smbData: [bolusGraphStruct] = []
    var statsCarbData: [carbGraphStruct] = [], carbData: [carbGraphStruct] = []
    var statsBasalData: [basalGraphStruct] = [], basalData: [basalGraphStruct] = []
    var statsCacheLastUpdated: Date?
    var basalScheduleData: [basalGraphStruct] = []
    func findNearestBGbyTime(needle: Double, haystack: [ShareGlucoseData], startingIndex: Int) -> (sgv: Double, foundIndex: Int) { (110, 0) }
    func calculateMaxBgGraphValue() -> Int { 300 }
    func findNearestBolusbyTime(timeWithin: Double, needle: Double, haystack: [bolusGraphStruct], startingIndex: Int) -> (offset: Bool, foundIndex: Int) { (false, 0) }
}
class LogManager {
    static let shared = LogManager()
    enum Category { case analysis, nightscout }
    func log(category: Category, message: @autoclosure () -> String, isDebug: Bool = false, limitIdentifier: String? = nil) {}
}
struct SickDayHistoryEntry { var date: Double }
class Storage {
    static let shared = Storage()
    var sickDayHistory: [SickDayHistoryEntry] = []
    func setSickDayHistoryEntry(for date: Date, notes: String?) {}
}
func IsNightscoutEnabled() -> Bool { true }
enum UserDefaultsRepository {
    struct Setting { var value = true }
    static let downloadTreatments = Setting()
}
class NightscoutUtils {
    enum EventType { case sgv, treatments }
    static var reply: Result<Any, Error> = .success([])
    static func executeDynamicRequest(eventType: EventType, parameters: [String: String], completion: @escaping (Result<Any, Error>) -> Void) { completion(reply) }
    static func executeRequest<T: Decodable>(eventType: EventType, parameters: [String: String], completion: @escaping (Result<T, Error>) -> Void) { completion(.failure(NSError(domain: "test", code: 1))) }
    static func parseDate(_ value: String) -> Date? { ISO8601DateFormatter().date(from: value) }
}
'''
tests = r'''
let fm = FileManager.default
let now = Date()
let t = now.timeIntervalSince1970
func check(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() { fatalError(message) }
}
func entry(_ id: String, _ date: Date, carbs: Double = 10) -> [String: Any] {
    ["_id": id, "created_at": ISO8601DateFormatter().string(from: date), "eventType": "Carb Correction", "carbs": carbs]
}
func fingerprint(_ directory: URL) throws -> [String: String] {
    guard fm.fileExists(atPath: directory.path) else { return [:] }
    var result: [String: String] = [:]
    for url in try fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) {
        let attrs = try fm.attributesOfItem(atPath: url.path)
        result[url.lastPathComponent] = "\(attrs[.systemFileNumber]!)|\(attrs[.modificationDate]!)|\(try Data(contentsOf: url).base64EncodedString())"
    }
    return result
}
let day = Calendar.current.startOfDay(for: now)
let oldDate = day.addingTimeInterval(-3 * 86400 + 3600)
let many = (0..<400).map { entry("old-\($0)", oldDate.addingTimeInterval(Double($0))) }
NightscoutCache.upsertTreatments(from: many)
let initial = try fingerprint(NightscoutCache.dir)
NightscoutCache.upsertTreatments(from: many.reversed())
check(try fingerprint(NightscoutCache.dir) == initial, "identical treatment batch rewrote a file")
NightscoutCache.upsertTreatments(from: [entry("old-1", oldDate.addingTimeInterval(1), carbs: 42)])
check(try NightscoutCache.readDay(oldDate).treatments.first { $0._id == "old-1" }?.carbs == 42, "old edit lost")
check(try NightscoutCache.readDay(oldDate).treatments.count == 400, "partial batch deleted older data")
let recent = now.addingTimeInterval(-3600)
NightscoutCache.mergeSGVBatch([SGVJSON(date: recent.timeIntervalSince1970, sgv: 100)])
NightscoutCache.upsertTreatments(from: [entry("recent", recent)])
NightscoutCache.refreshTreatmentsWindow(from: now.addingTimeInterval(-86400), to: now, entries: [entry("recent", recent, carbs: 30)])
check(try NightscoutCache.readDay(recent).treatments.first { $0._id == "recent" }?.carbs == 30, "recent edit lost")
let refreshed = try fingerprint(NightscoutCache.dir)
NightscoutCache.refreshTreatmentsWindow(from: now.addingTimeInterval(-86400), to: now, entries: [entry("recent", recent, carbs: 30)])
check(try fingerprint(NightscoutCache.dir) == refreshed, "unchanged refresh rewrote a day")
NightscoutCache.refreshTreatmentsWindow(from: now.addingTimeInterval(-86400), to: now, entries: [])
check(try NightscoutCache.readDay(recent).treatments.isEmpty, "empty snapshot failed to delete recent treatment")
check(try NightscoutCache.readDay(recent).sgv.count == 1, "treatment refresh deleted glucose")
check(try NightscoutCache.readDay(oldDate).treatments.count == 400, "recent deletion touched old day")
// Concurrent BG and treatment transactions on the same day must preserve both.
DispatchQueue.concurrentPerform(iterations: 80) { i in
    let sampleTime = oldDate.addingTimeInterval(Double(i) * 300)
    if i % 2 == 0 { NightscoutCache.upsertTreatment(from: entry("concurrent-\(i)", sampleTime)) }
    else { NightscoutCache.mergeSGVBatch([SGVJSON(date: sampleTime.timeIntervalSince1970, sgv: 110)]) }
}
check(try NightscoutCache.readDay(oldDate).treatments.count == 440, "concurrent treatment update lost")
check(try NightscoutCache.readDay(oldDate).sgv.count == 40, "concurrent BG update lost")
print("PASS treatment batching, no-op writes, edits, deletions, partial history and concurrent BG/treatments")

let root = testRoot.appendingPathComponent("stats")
try fm.createDirectory(at: root, withIntermediateDirectories: true)
let legacyURL = root.appendingPathComponent("StatsCache.json")
let legacy: [String: Any] = ["lastUpdated": now.timeIntervalSinceReferenceDate,
    "bg": [["date": t - 80 * 86400, "sgv": 100], ["date": t - 3600, "sgv": 110]],
    "bgChecks": [["date": t - 1800]],
    "bolus": [["date": t - 70 * 86400, "value": 1.0, "sgv": 100], ["date": t - 3600, "value": 2.0, "sgv": 110]],
    "smb": [], "carbs": [["date": t - 3600, "value": 10.0, "sgv": 110, "absorptionTime": 120, "fat": 0, "protein": 0]],
    "basal": []]
let legacyData = try JSONSerialization.data(withJSONObject: legacy)
try legacyData.write(to: legacyURL)
let manager = StatsCacheManager(directory: root)
let vc = MainViewController()
manager.loadInto(mainVC: vc)
check(vc.statsBGData.count == 2 && vc.statsBolusData.count == 2, "legacy history not loaded")
manager.saveFrom(mainVC: vc)
check(try Data(contentsOf: legacyURL) == legacyData, "rollback copy changed")
let shardDir = root.appendingPathComponent("StatsCacheDays-v1")
let migrated = try fingerprint(shardDir)
manager.saveFrom(mainVC: vc)
check(try fingerprint(shardDir) == migrated, "unchanged statistics rewrote files")
vc.bolusData = [.init(value: 3, date: t - 3600, sgv: 110)]
vc.carbData = [.init(value: 35, date: t - 3600, sgv: 110, absorptionTime: 180, foodType: "edited", fat: 4, protein: 5)]
vc.stats_syncTreatmentsFromLive(replacingRecentSince: now.addingTimeInterval(-86400))
check(vc.statsBolusData.first { $0.date == t - 3600 }?.value == 3, "stats bolus edit ignored")
check(vc.statsCarbData.first?.value == 35, "stats meal edit ignored")
check(vc.statsBGCheckData.isEmpty, "deleted fingerstick persisted in stats")
check(vc.statsBolusData.contains { $0.date == t - 70 * 86400 }, "old stats lost")
manager.saveFrom(mainVC: vc)
let updated = try fingerprint(shardDir)
check(updated.filter { migrated[$0.key] != $0.value }.count == 1, "recent change rewrote old stats days")
manager.loadInto(mainVC: vc)
check(vc.statsCarbData.first?.value == 35, "repeated service creation overwrote live state")
vc.bolusData = []; vc.carbData = []
vc.stats_syncTreatmentsFromLive(replacingRecentSince: now.addingTimeInterval(-86400))
manager.saveFrom(mainVC: vc)
let restarted = MainViewController()
StatsCacheManager(directory: root).loadInto(mainVC: restarted)
check(restarted.statsBolusData.count == 1 && restarted.statsCarbData.isEmpty && restarted.statsBGCheckData.isEmpty, "deleted stats resurrected on relaunch")
check(restarted.statsBGData.count == 2, "old BG history lost on migration/relaunch")
let export = testRoot.appendingPathComponent("export.json")
manager.exportMonthStatsCache(interval: DateInterval(start: now.addingTimeInterval(-91 * 86400), end: now), destinationURL: export)
let exported = try JSONSerialization.jsonObject(with: Data(contentsOf: export)) as! [String: Any]
check((exported["bg"] as! [Any]).count == 2, "archive ignored daily shards")
check((exported["carbs"] as! [Any]).isEmpty, "archive exported stale legacy data")
// Retention deletes the expired shard without rewriting unrelated days.
vc.statsBGData.append(.init(sgv: 99, date: t - 92 * 86400, direction: nil))
manager.saveFrom(mainVC: vc)
check(!vc.statsBGData.isEmpty, "retention altered live arrays")
let afterRetention = MainViewController()
StatsCacheManager(directory: root).loadInto(mainVC: afterRetention)
check(afterRetention.statsBGData.count == 2, "expired BG persisted")
// A failure before migration must not publish a partial directory or destroy legacy data.
let failedRoot = testRoot.appendingPathComponent("failed")
try fm.createDirectory(at: failedRoot, withIntermediateDirectories: true)
try legacyData.write(to: failedRoot.appendingPathComponent("StatsCache.json"))
try Data().write(to: failedRoot.appendingPathComponent("StatsCacheDays-v1"))
let failedVC = MainViewController(), failedManager = StatsCacheManager(directory: failedRoot)
failedManager.loadInto(mainVC: failedVC); failedManager.saveFrom(mainVC: failedVC)
check(try Data(contentsOf: failedRoot.appendingPathComponent("StatsCache.json")) == legacyData, "failed migration destroyed legacy")
check(!fm.fileExists(atPath: failedRoot.appendingPathComponent("StatsCacheDays-v1/_complete").path), "failed migration published marker")
print("PASS stats migration, no-op writes, day-only updates, recent edits/deletions, restart, export, retention and failed migration")
// Exercise the real stats-fetch response path: changed values, deletions, failures and caps.
let fetchVC = MainViewController()
let dataFetcher = StatsDataFetcher(mainViewController: fetchVC)
fetchVC.statsBolusData = [.init(value: 1, date: t - 70 * 86400, sgv: 100)]
func fetch(_ response: Result<Any, Error>) {
    NightscoutUtils.reply = response
    var completed = false
    dataFetcher.fetchTreatmentsData(days: 2) { completed = true }
    let deadline = Date().addingTimeInterval(5)
    while !completed && Date() < deadline { RunLoop.current.run(until: Date().addingTimeInterval(0.01)) }
    check(completed, "stats request did not complete")
}
var meal = entry("meal", recent, carbs: 20)
meal["eventType"] = "Meal Bolus"; meal["insulin"] = 2.0
meal["absorptionTime"] = 120
fetch(.success([meal]))
check(fetchVC.statsCarbData.first?.value == 20, "initial meal fetch missing")
meal["carbs"] = 45.0; meal["insulin"] = 3.0; meal["absorptionTime"] = 180
fetch(.success([meal]))
check(fetchVC.statsCarbData.count == 1 && fetchVC.statsCarbData[0].value == 45 && fetchVC.statsCarbData[0].absorptionTime == 180, "same-timestamp meal edit ignored by fetch")
check(fetchVC.statsBolusData.last?.value == 3, "same-timestamp insulin edit ignored by fetch")
fetch(.failure(NSError(domain: "test", code: 2)))
check(fetchVC.statsCarbData.count == 1, "failed fetch deleted data")
fetch(.success(Array(repeating: meal, count: 60000)))
check(fetchVC.statsCarbData.count == 1, "capped fetch changed data")
fetch(.success([[String: Any]]()))
check(fetchVC.statsCarbData.isEmpty && fetchVC.statsBolusData.count == 1, "empty successful fetch failed to delete recent data or removed older history")
// Live BG corrections must update a previously cached five-minute bucket.
fetchVC.statsBGData = [.init(sgv: 100, date: t - 3600, direction: nil)]
fetchVC.bgData = [.init(sgv: 115, date: t - 3600, direction: nil)]
fetchVC.stats_syncBGFromLive()
check(fetchVC.statsBGData.count == 1 && fetchVC.statsBGData[0].sgv == 115, "live BG correction ignored")
// Deleting the final item in a shard must not resurrect it from the old monolithic file.
let emptyRoot = testRoot.appendingPathComponent("empty-stats")
try fm.createDirectory(at: emptyRoot, withIntermediateDirectories: true)
try legacyData.write(to: emptyRoot.appendingPathComponent("StatsCache.json"))
let emptyManager = StatsCacheManager(directory: emptyRoot), emptyVC = MainViewController()
emptyManager.loadInto(mainVC: emptyVC); emptyManager.saveFrom(mainVC: emptyVC)
emptyVC.statsBGData = []; emptyVC.statsBGCheckData = []; emptyVC.statsBolusData = []; emptyVC.statsCarbData = []
emptyManager.saveFrom(mainVC: emptyVC)
let emptyRestart = MainViewController()
StatsCacheManager(directory: emptyRoot).loadInto(mainVC: emptyRestart)
check(emptyRestart.statsBGData.isEmpty && emptyRestart.statsBolusData.isEmpty, "empty migrated cache resurrected legacy records")
print("PASS actual stats fetch: edits, deletions, failed/capped replies, BG corrections and empty-shard restart")

'''
# Throwing assertions keep expressions readable without swallowing I/O failures.
tests = tests.replace('func check(_ condition: @autoclosure () -> Bool, _ message: String) {\n    if !condition()', 'func check(_ condition: @autoclosure () throws -> Bool, _ message: String) rethrows {\n    if try !condition()')
tests = tests.replace('check(try ', 'try check(try ')
with tempfile.TemporaryDirectory(prefix='loopfollow-cache-tests-') as directory:
    temp = Path(directory)
    source = temp / 'main.swift'
    source.write_text(stubs + '\n' + nightscout + '\n' + stats + '\n' + fetcher + '\n' + tests)
    binary = temp / 'cache-tests'
    subprocess.run(['xcrun', 'swiftc', '-swift-version', '5', '-module-cache-path', str(temp / 'modules'), str(source), '-o', str(binary)], check=True)
    subprocess.run([str(binary), str(temp / 'data')], check=True)
