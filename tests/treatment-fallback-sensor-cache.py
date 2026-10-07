#!/usr/bin/env python3
"""Exercise both live treatment fallbacks through the sensor-error builder."""
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
def section(path, start, end):
    source = (root / path).read_text()
    begin = source.index(start)
    return source[begin:source.index(end, begin)]
source = (root / 'LoopFollow/Views/Treatments/TreatmentsTableView+Loading.swift').read_text()
fallbacks = source[source.index('    func fetchDynamicTreatments(for date: Date,'):].removesuffix('\n').removesuffix('}')
models = section('LoopFollow/Controllers/NightscoutCache.swift', 'struct SGVJSON:', '// One day’s payload')
outages = section('LoopFollow/Storage/Storage.swift', 'struct DexcomSensorErrorOutageCacheItem:', 'struct PumpChangeHistoryEntry:')
fixture = r'''
import Foundation
struct Treatment {
    let timestamp: Date
    init?(dictionary: [String: AnyObject]) {
        guard let raw = dictionary["created_at"] as? String,
              let date = TreatmentJSON.parseTrioSentAt(raw) else { return nil }
        timestamp = date
    }
}
class Table { var reloads = 0; func reloadData() { reloads += 1 } }
class TreatmentsTableView {
    var treatments: [Treatment] = []
    let tableView = Table()
    FALLBACKS
}
struct ObservableUserDefaults {
    static let shared = ObservableUserDefaults()
    struct Setting { let value = "test" }
    let url = Setting()
}
struct RemoteCommandReceiptTracker {
    static let shared = RemoteCommandReceiptTracker()
    func observeDeletions(_ entries: [[String: Any]], site: String, requestStartedAt: Date,
                         from: Date, through: Date, responseLimit: Int) {}
}
struct NightscoutUtils {
    enum Event { case treatments }
    static var response: Result<Any, Error> = .success([])
    static func parseDate(_ raw: String) -> Date? { TreatmentJSON.parseTrioSentAt(raw) }
    static func executeDynamicRequest(eventType: Event, parameters: [String: String],
                                      completion: @escaping (Result<Any, Error>) -> Void) { completion(response) }
}
struct NightscoutCache {
    static var stored: [String: TreatmentJSON] = [:]
    static func upsertTreatments(from entries: [[String: Any]]) {
        for item in entries.compactMap({ TreatmentJSON(dict: $0) }) { stored[item._id] = item }
    }
}
@main struct Check {
    static func main() async {
        let iso = ISO8601DateFormatter()
        let start = iso.date(from: "2026-10-05T23:29:46Z")!
        let now = iso.date(from: "2026-10-07T06:30:00Z")!
        let records: [[String: AnyObject]] = [
            ["_id": "error1", "created_at": "2026-10-06T19:13:00Z", "eventType": "Note", "notes": "⚠️ Dexcom G7: Tillfälligt sensorfel!", "trioSentAt": "2026-10-06T19:13:01Z"],
            ["_id": "recovery1", "created_at": "2026-10-06T19:18:00Z", "eventType": "Note", "notes": "✅ Dexcom G7: Sensor återställd!"],
            ["_id": "error2", "created_at": "2026-10-06T19:23:00Z", "eventType": "Note", "notes": "⚠️ Dexcom G7: Tillfälligt sensorfel!", "trioSentAt": "2026-10-06T19:23:01Z"],
            ["_id": "recovery2", "created_at": "2026-10-06T19:28:00Z", "eventType": "Note", "notes": "✅ Dexcom G7: Sensor återställd!"]
        ].map { $0.mapValues { $0 as AnyObject } }
        let readings = ["2026-10-06T19:18:00Z", "2026-10-06T19:28:00Z"].map {
            SGVJSON(date: iso.date(from: $0)!.timeIntervalSince1970, sgv: 100)
        }
        NightscoutUtils.response = .success(records)
        let view = TreatmentsTableView()
        for callbackVariant in [true, false] {
            NightscoutCache.stored = [:]
            if callbackVariant {
                await withCheckedContinuation { continuation in
                    view.fetchDynamicTreatments(for: start) { rows in
                        precondition(rows.count == 4)
                        precondition(NightscoutCache.stored.count == 4, "Cache must be populated before displaying fetched rows")
                        continuation.resume()
                    }
                }
            } else {
                view.fetchDynamicTreatments(for: start)
                for _ in 0..<1000 {
                    if view.tableView.reloads > 0 { break }
                    try! await Task.sleep(nanoseconds: 1_000_000)
                }
                precondition(view.treatments.count == 4)
                precondition(NightscoutCache.stored.count == 4, "Legacy fallback must also feed sensor history")
            }
            let errors = DexcomSensorErrorOutageCacheItem.build(readings: readings,
                treatments: Array(NightscoutCache.stored.values), now: now)
            precondition(errors.count == 2 && errors.allSatisfy { $0.durationMinutes == 5 })
            precondition(errors.allSatisfy { $0.sensorErrorTimestamp > start.timeIntervalSince1970 && $0.sensorErrorTimestamp < now.timeIntervalSince1970 })
            precondition(errors.allSatisfy { $0.trioSentAt != nil }, "Preserve upload timestamps used for session ownership")
        }
        // Failed fetches must not erase existing cached errors.
        NightscoutUtils.response = .failure(NSError(domain: "test", code: 1))
        await withCheckedContinuation { continuation in
            view.fetchDynamicTreatments(for: start) { rows in
                precondition(rows.isEmpty && NightscoutCache.stored.count == 4)
                continuation.resume()
            }
        }
        print("Both treatment fallbacks populate the sensor cache; screenshot errors yield 2 x 5 minutes; failed fetch preserves cache")
    }
}
'''.replace('    FALLBACKS', fallbacks)
with tempfile.TemporaryDirectory(prefix='treatment-fallback-') as tmp:
    tmp = Path(tmp)
    swift = tmp / 'checks.swift'
    swift.write_text(fixture + models + outages)
    subprocess.run(['xcrun', 'swiftc', '-swift-version', '5', '-parse-as-library', '-module-cache-path', str(tmp / 'modules'), str(swift), '-o', str(tmp / 'checks')], check=True)
    subprocess.run([str(tmp / 'checks')], check=True)
