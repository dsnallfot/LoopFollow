#!/usr/bin/env python3
"""Execute production category/index/page/cache code with temporary files (macOS + Swift).
Run: python3 tests/treatment-category-search.py
"""
from pathlib import Path
import os
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
cache = (root / 'LoopFollow/Controllers/NightscoutCache.swift').read_text()
cache = cache[cache.index('struct SGVJSON:'):cache.index('// MARK: - Battery history')]
cache = cache.replace('FileManager.default\n            .urls(for: .cachesDirectory, in: .userDomainMask)[0]', 'testRoot')
cache = cache.replace('        struct TreatmentsPayload: Decodable', '        searchReadCount += 1\n        struct TreatmentsPayload: Decodable')
models = root / 'LoopFollow/Views/Treatments/Models'
source = r'''
import Foundation
let testRoot = URL(fileURLWithPath: CommandLine.arguments[1])
var searchReadCount = 0
class NightscoutUtils {
    static var parseCount = 0
    static func parseDate(_ value: String) -> Date? {
        parseCount += 1
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: value) ?? ISO8601DateFormatter().date(from: value)
    }
}
struct SickDayHistoryEntry { var date: Double }
class Storage {
    static let shared = Storage()
    var sickDayHistory: [SickDayHistoryEntry] = []
    func setSickDayHistoryEntry(for date: Date, notes: String?) {}
}
class LogManager {
    static let shared = LogManager()
    enum Category { case nightscout }
    func log(category: Category, message: String, limitIdentifier: String? = nil) {}
}
'''
source += cache + (models / 'Treatment.swift').read_text() + (models / 'TreatmentSearchIndex.swift').read_text()
# Use the real local mutation helpers with a data-only table/controller spy.
helpers = (root / 'LoopFollow/Views/Treatments/TreatmentsTableView+Cache.swift').read_text()
helpers = helpers[helpers.index('    private func matchesTreatment'):helpers.index('    // MARK: - Rolling Window')]
source += r'''
class TableSpy { func reloadData() {} }
class TreatmentsTableView {
    struct TreatmentDaySection { let date: Date; var treatments: [Treatment] }
    var daySections: [TreatmentDaySection] = []
    var treatments: [Treatment] = []
    let tableView = TableSpy()
    func updateDuplicateIndicator() {}
    func rebuildTreatmentsFlatCache() { treatments = daySections.flatMap { $0.treatments } }
    func daySectionIndex(for date: Date) -> Int? {
        daySections.firstIndex { Calendar.current.isDate($0.date, inSameDayAs: date) }
    }
''' + helpers + '\n}\n'
source += r'''
let calendar = Calendar.current
let today = calendar.startOfDay(for: Date())
let day = calendar.date(byAdding: .day, value: -30, to: today)!
let iso = ISO8601DateFormatter()
iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
func record(_ id: String, _ type: String, food: String = "", notes: String = "", at date: Date? = nil) -> TreatmentJSON {
    TreatmentJSON(dict: ["_id": id, "created_at": iso.string(from: date ?? day.addingTimeInterval(3600.125)),
        "eventType": type, "foodType": food, "notes": notes, "carbs": 12.5, "duration": 30])!
}
let auto = ["Temp Basal", "SMB"]
let manual = ["Carb Correction", "Kolhydrater", "Dextro", "Måltid", "Bolus", "Correction Bolus", "Meal Bolus", "Insulinpenna", "Exercise", "BG Check"]
let sensor = record("sensor", "Sensor Start", notes: "pizza")
let pump = record("pump", "Site Change")
let fat = record("fat", "Carb Correction")
let meal = record("meal", "Carb Correction", food: "pizza", notes: "sensorbyte")
let dextro = record("dextro", "Carb Correction", food: "socker", notes: "✎ 🍬🍬")
let fixture = [sensor, pump, fat, meal, dextro, record("smb", "SMB"), record("bg", "BG Check"),
    record("note", "Note", notes: "pumpbyte"), record("alias", "Sensor Change")]
let index = TreatmentSearchIndex(records: fixture + [sensor])
func ids(_ query: String, segment: Int = 0) -> Set<String> {
    Set(index.matches(query: query, segment: segment, autoTypes: auto, manualTypes: manual).map(\._id))
}
precondition(ids("SENSORBYTE") == ["sensor", "alias"])
precondition(ids("sensor") == ["sensor", "alias"])
precondition(ids("pumpbyte") == ["pump", "note"])
precondition(ids("pumbyte") == ["pump"])
for query in ["Fett/Protein", "fett & protein", "FPU", "protein fett"] {
    precondition(ids(query) == ["fat"], query)
}
precondition(ids("maltid") == ["meal"])
precondition(ids("dextro") == ["dextro"])
precondition(ids("pizza").isEmpty, "Do not search notes or food on other treatment types")
precondition(ids("fingerstick") == ["bg"])
precondition(ids("sensor", segment: 2).isEmpty)
precondition(ids("sensor", segment: 3) == ["sensor", "alias"])
precondition(ids("smb", segment: 1) == ["smb"])
precondition(ids("fpu", segment: 2).isEmpty, "Preserve existing segment rules")
precondition(ids("  / & ").isEmpty)
precondition(ids("saknas").isEmpty)

// Free text is restricted to Note, with all words required in the same record.
let notesIndex = TreatmentSearchIndex(records: [
    record("loop", "Note", notes: "Loop-fel: pumpen svarar inte"),
    record("dexcom", "Note", notes: "Dexcom G7: Sensorfel – försök igen"),
    record("empty", "Note"),
    record("announcement", "Announcement", notes: "Dexcom"),
    record("other", "Sensor Start", notes: "Dexcom"),
    record("duplicates", "Note", notes: "Note Loop"),
    record("duplicates", "Note", notes: "Note Loop")
])
func noteIDs(_ query: String, segment: Int = 0) -> Set<String> {
    let hits = notesIndex.matches(query: query, segment: segment, autoTypes: auto, manualTypes: manual)
    precondition(hits.count == Set(hits.map(\._id)).count, "Duplicate category/text match")
    return Set(hits.map(\._id))
}
precondition(noteIDs("LOOP") == ["loop", "duplicates"])
precondition(noteIDs("dexcom") == ["dexcom"])
precondition(noteIDs("Sensorfel") == ["dexcom"])
precondition(noteIDs("forsok G7") == ["dexcom"])
precondition(noteIDs("notering dexcom") == ["dexcom"])
precondition(noteIDs("loop dexcom").isEmpty)
precondition(noteIDs("dexcom", segment: 1).isEmpty)
precondition(noteIDs("dexcom", segment: 2).isEmpty)
precondition(noteIDs("dexcom", segment: 3) == ["dexcom"])
precondition(noteIDs("note") == ["loop", "dexcom", "empty", "duplicates", "announcement"], "Keep existing category alias matches")

// Typed conversion retains fractional timestamps and raw fields for editing/deleting.
let beforeParse = NightscoutUtils.parseCount
let converted = Treatment(cached: meal, dateFormatter: iso)
precondition(NightscoutUtils.parseCount == beforeParse, "Cached dates must not be reparsed")
precondition(converted.timestamp == meal.created_at && converted.amount == "12.5 g")
precondition(converted.documentId == meal._id && converted.category == .meal)
precondition(converted.rawData["foodType"] as? String == "pizza")
precondition(iso.date(from: converted.rawData["created_at"] as! String) == meal.created_at)
precondition(Treatment(dictionary: converted.rawData)?.timestamp == meal.created_at)

try NightscoutCache.writeDay(date: day, sgv: [], treatments: fixture)
let initialRevision = NightscoutCache.treatmentSearchRevision
try NightscoutCache.writeDay(date: day, sgv: [SGVJSON(date: day.timeIntervalSince1970, sgv: 123)], treatments: fixture)
precondition(NightscoutCache.treatmentSearchRevision == initialRevision, "Glucose must not invalidate category index")
let store = TreatmentSearchStore()
func waitFor<T>(_ operation: (@escaping (T) -> Void) -> Void) -> T {
    var result: T?
    operation { result = $0 }
    let deadline = Date().addingTimeInterval(10)
    while result == nil && Date() < deadline {
        RunLoop.current.run(until: Date().addingTimeInterval(0.01))
    }
    precondition(result != nil, "Background search timed out")
    return result!
}
func search(_ query: String) -> TreatmentSearchStore.Result {
    waitFor { done in store.search(query: query, segment: 0, autoTypes: auto, manualTypes: manual,
                                  scope: "fixture", completion: done) }
}
let first = search("sensor")
precondition(Set(first.records.map(\._id)) == ["sensor", "alias"], "Search days that were never scrolled in")
precondition(first.dayCount == 91 && first.unavailableDays == 90)
let reads = searchReadCount
precondition(search("pump").records.count == 2)
precondition(searchReadCount == reads, "Unchanged cache should reuse the index")

// Note text is cached too, and an edit invalidates the old words.
precondition(search("notering pumpbyte").records.map(\._id) == ["note"])
precondition(searchReadCount == reads)
NightscoutCache.upsertTreatment(from: ["_id": "note", "eventType": "Note", "notes": "Dexcom sensorfel",
    "created_at": iso.string(from: day.addingTimeInterval(3600.125))])
precondition(search("dexcom").records.map(\._id) == ["note"])
precondition(search("notering pumpbyte").records.isEmpty)

// A missing or unreadable file is not silently treated as complete history.
let unreadable = calendar.date(byAdding: .day, value: -2, to: today)!
try NightscoutCache.writeDay(date: unreadable, sgv: [], treatments: [])
let files = try FileManager.default.contentsOfDirectory(at: NightscoutCache.dir, includingPropertiesForKeys: nil)
let emptyFile = try files.first { try JSONDecoder().decode(DayPayload.self, from: Data(contentsOf: $0)).treatments.isEmpty }!
try Data("not json".utf8).write(to: emptyFile)
precondition(search("pump").unavailableDays == 90)

// Rebuild after deletion, then restoration/edit of a historic record.
try NightscoutCache.writeDay(date: day, sgv: [], treatments: fixture.filter { $0._id != "sensor" })
precondition(search("sensor").records.map(\._id) == ["alias"])
NightscoutCache.upsertTreatment(from: ["_id": "sensor", "eventType": "Site Change", "created_at": iso.string(from: sensor.created_at)])
precondition(Set(search("pump").records.map(\._id)) == ["sensor", "pump", "note"])

// Large result sets stay raw until a requested page is prepared, in descending date order.
let many = (0..<250).map { record("basal-\($0)", "Temp Basal", at: day.addingTimeInterval(Double($0) + 7200)) }
try NightscoutCache.writeDay(date: day, sgv: [], treatments: many)
let hits = search("basal").records
precondition(hits.count == 250 && hits.first?._id == "basal-249" && hits.last?._id == "basal-0")
let page: TreatmentSearchStore.Page = waitFor { store.preparePage(Array(hits.prefix(100)), completion: $0) }
precondition(page.treatments.count == 100 && page.glucose.isEmpty)
let next: TreatmentSearchStore.Page = waitFor { store.preparePage(Array(hits.dropFirst(100).prefix(100)), completion: $0) }
precondition(next.treatments.first?.documentId == "basal-149")

// A meal late at night needs glucose from the following day too.
let lateMeal = record("late", "Carb Correction", food: "mat", at: day.addingTimeInterval(23 * 3600))
let nextDay = calendar.date(byAdding: .day, value: 1, to: day)!
try NightscoutCache.writeDay(date: nextDay, sgv: [SGVJSON(date: nextDay.addingTimeInterval(7200).timeIntervalSince1970, sgv: 120)], treatments: [])
let mealPage: TreatmentSearchStore.Page = waitFor { store.preparePage([lateMeal], completion: $0) }
precondition(mealPage.glucose[nextDay]?.count == 1)

// Exact local-day window excludes older records and the next midnight.
let oldest = calendar.date(byAdding: .day, value: -90, to: today)!
let tooOld = oldest.addingTimeInterval(-1)
let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
try NightscoutCache.writeDay(date: oldest, sgv: [], treatments: [record("edge", "Site Change", at: oldest), record("old", "Site Change", at: tooOld)])
try NightscoutCache.writeDay(date: today, sgv: [], treatments: [record("tomorrow", "Site Change", at: tomorrow)])
precondition(search("pump").records.map(\._id) == ["edge"])
// Historic search hits need not exist in the normal browsing snapshot.
let view = TreatmentsTableView()
let old = record("edit-old", "Note", at: day.addingTimeInterval(8000))
try NightscoutCache.writeDay(date: day, sgv: [], treatments: [old])
view.replaceLocalTreatment(Treatment(cached: old, dateFormatter: iso), with: [
    "_id": "edit-new", "eventType": "Note", "notes": "edited", "created_at": iso.string(from: old.created_at)])
precondition(search("note").records.map(\._id) == ["edit-new"], "Old search-only document survived edit")
precondition(view.daySections.isEmpty, "Search edit should not insert unrelated browsing sections")

// Edits and optimistic delete/restore must also keep existing normal day sections coherent.
let newRecord = search("note").records.first!
let newTreatment = Treatment(cached: newRecord, dateFormatter: iso)
view.daySections = [.init(date: day, treatments: [newTreatment])]
view.rebuildTreatmentsFlatCache()
view.applyLocalTreatmentDeletion(newTreatment)
precondition(view.daySections[0].treatments.isEmpty && search("note").records.isEmpty)
view.restoreLocalTreatment(newTreatment)
precondition(view.daySections[0].treatments.count == 1 && search("note").records.count == 1)
view.replaceLocalTreatment(newTreatment, with: ["_id": "moved", "eventType": "Note", "notes": "moved",
    "created_at": iso.string(from: nextDay.addingTimeInterval(3600))])
precondition(view.daySections[0].treatments.isEmpty && search("note").records.map(\._id) == ["moved"])
if ProcessInfo.processInfo.environment["SEARCH_BENCHMARK"] == "1" {
    let template = try JSONSerialization.jsonObject(with: JSONEncoder().encode(sensor)) as! [String: Any]
    let documents: [[String: Any]] = (0..<50000).map { i in
        var document = template
        document["_id"] = "benchmark-\(i)"
        document["eventType"] = i % 5 == 0 ? "Note" : "Temp Basal"
        document["notes"] = i % 5 == 0 ? "Loop-fel: Dexcom G7 rapporterar sensorfel, försök igen om en stund" : ""
        return document
    }
    let records = try JSONDecoder().decode([TreatmentJSON].self, from: JSONSerialization.data(withJSONObject: documents))
    let start = DispatchTime.now().uptimeNanoseconds
    let benchmark = TreatmentSearchIndex(records: records)
    print(String(format: "Index, 50000 records / 10000 notes: %.1f ms", Double(DispatchTime.now().uptimeNanoseconds - start) / 1e6))
    for query in ["basal", "Dexcom", "Sensorfel", "Loop", "forsok igen", "saknas"] {
        let start = DispatchTime.now().uptimeNanoseconds
        var count = 0
        for _ in 0..<10 { count += benchmark.matches(query: query, segment: 0, autoTypes: auto, manualTypes: manual).count }
        print(String(format: "Search %@: %.1f ms average, %d hits", query, Double(DispatchTime.now().uptimeNanoseconds - start) / 1e7, count / 10))
    }
}
print("Category search passed: aliases, shared categories, segment filters, cache-only history, index reuse/invalidation, raw-data preservation, paging, meal glucose and date boundaries")
'''
with tempfile.TemporaryDirectory(prefix='category-search-tests-') as temp:
    path = Path(temp) / 'main.swift'
    path.write_text(source)
    env = dict(os.environ, CLANG_MODULE_CACHE_PATH=temp + '/modules')
    subprocess.run(['swiftc', '-O', str(path), '-o', temp + '/test'], check=True, env=env)
    subprocess.run([temp + '/test', temp + '/cache'], check=True, env=env)
