#!/usr/bin/env python3
"""Exercise production sensor ownership, outage building and duration buckets with Swift."""
from pathlib import Path
import subprocess
import tempfile

repo = Path(__file__).resolve().parents[1]
def section(path, start, end):
    text = (repo / path).read_text()
    return text[text.index(start):text.index(end, text.index(start))]

models = section('LoopFollow/Storage/Storage.swift', 'struct SensorStartHistoryEntry:', 'struct PumpChangeHistoryEntry:')
treatment = section('LoopFollow/Controllers/NightscoutCache.swift', 'struct TreatmentJSON:', '// One day’s payload')
view = 'LoopFollow/Views/SensorHistoryView.swift'
buckets = section(view, 'struct SessionBuckets', 'class SensorHistoryViewController')
builder = section(view, '    private func buildDexcomOutageItems', '    private func formatTotalDuration').replace('private func', 'func')
counts = section(view, '    private func computeSessionBuckets', '    func tableView(').replace('private func', 'func')
stubs = '''
import Foundation
class LogManager {
    static let shared = LogManager()
    enum Category { case bluetooth }
    func log(category: Category, message: String) {}
}
struct NightscoutUtils {
    static func parseDate(_ raw: String) -> Date? { TreatmentJSON.parseTrioSentAt(raw) }
}
struct SGVJSON { var date: TimeInterval; var sgv: Int; var readingDate: Date { Date(timeIntervalSince1970: date) } }
'''
checks = r'''
func date(_ seconds: Double) -> Date { Date(timeIntervalSince1970: seconds) }
let old = SensorStartHistoryEntry(date: 0, note: "old", trioSentAt: date(100))
let new = SensorStartHistoryEntry(date: 7200, note: "new", trioSentAt: date(18000.275))
let history = [new, old]
let now = date(30000)
let oldWindow = old.sensorUsageWindow(in: history, now: now)
let newWindow = new.sensorUsageWindow(in: history, now: now)
precondition(oldWindow.contains(12000), "Overlap belongs to old sensor")
precondition(!newWindow.contains(12000))
precondition(oldWindow.contains(18000.274), "Fractional boundary must be preserved")
precondition(!oldWindow.contains(18000.275))
precondition(newWindow.contains(18000.275), "Boundary belongs to new sensor")
precondition(new.date == 7200, "Activation must not move")
let legacy = try JSONDecoder().decode(SensorStartHistoryEntry.self, from: Data(#"{"date":7200,"note":"legacy"}"#.utf8))
precondition(legacy.usageStartTimestamp == 7200)
let legacyOutage = try JSONDecoder().decode(DexcomSensorErrorOutageCacheItem.self, from: Data(#"{"noteTimestamp":12000,"startTimestamp":11900,"endTimestamp":12300}"#.utf8))
precondition(legacyOutage.sensorErrorTimestamp == 12000)
let parsed = TreatmentJSON.parseTrioSentAt("2026-10-01T17:20:06.275Z")!
let whole = TreatmentJSON.parseTrioSentAt("2026-10-01T17:20:06Z")!
precondition(abs(parsed.timeIntervalSince(whole) - 0.275) < 0.00001)
precondition(TreatmentJSON.parseTrioSentAt("2026-10-01T19:20:06.275+02:00") == parsed)
precondition(TreatmentJSON.parseTrioSentAt("invalid") == nil)
let note = TreatmentJSON(dict: ["_id": "test", "created_at": "1970-01-01T03:20:00Z", "eventType": "Note", "notes": "Dexcom error", "trioSentAt": "1970-01-01T03:21:00.275Z"])!
let harness = Harness()
let items = harness.buildDexcomOutageItems(allSGV: [SGVJSON(date: 11900, sgv: 100), SGVJSON(date: 12300, sgv: 100)], allTreatments: [note], now: now)
precondition(items.count == 1)
precondition(items[0].noteTimestamp == 12000)
precondition(items[0].startTimestamp == 12000 && items[0].endTimestamp == 12300, "Duration starts at the note, not the preceding SGV")
precondition(abs(items[0].sensorErrorTimestamp - 12060.275) < 0.00001)
precondition(oldWindow.contains(items[0].sensorErrorTimestamp))
let roundTrip = try JSONDecoder().decode([DexcomSensorErrorOutageCacheItem].self, from: JSONEncoder().encode(items))
precondition(roundTrip == items)
let roundTripHistory = try JSONDecoder().decode([SensorStartHistoryEntry].self, from: JSONEncoder().encode(history))
precondition(roundTripHistory[0].trioSentAt == new.trioSentAt)
var legacyJSON = try JSONSerialization.jsonObject(with: JSONEncoder().encode(note)) as! [String: Any]
legacyJSON.removeValue(forKey: "trioSentAt")
let cachedLegacy = try JSONDecoder().decode(TreatmentJSON.self, from: JSONSerialization.data(withJSONObject: legacyJSON))
precondition(cachedLegacy.trioSentAt == nil)
harness.sensorHistory = history
precondition(harness.computeSessionBuckets().hrs_total == 5, "Previous session ends at pairing, not activation at 2h")
print("Sensor timestamp regressions passed")
'''
with tempfile.TemporaryDirectory(prefix='sensor-timestamps-') as temp:
    temp = Path(temp)
    source = temp / 'main.swift'
    source.write_text(stubs + models + treatment + buckets + '\nclass Harness { var sensorHistory: [SensorStartHistoryEntry] = []\n' + builder + counts + '\n}\n' + checks)
    binary = temp / 'checks'
    subprocess.run(['xcrun', 'swiftc', '-swift-version', '5', '-module-cache-path', str(temp / 'modules'), str(source), '-o', str(binary)], check=True)
    subprocess.run([str(binary)], check=True)
