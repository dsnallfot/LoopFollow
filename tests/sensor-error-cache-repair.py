#!/usr/bin/env python3
"""Exercise production note-to-recovery calculation, fingersticks and cache repair."""
from pathlib import Path
import subprocess
import tempfile
repo = Path(__file__).resolve().parents[1]
def read(path): return (repo / path).read_text()
def section(path, start, end):
    s = read(path); a = s.index(start)
    return s[a:s.index(end, a)]
model = section('LoopFollow/Storage/Storage.swift', 'struct DexcomSensorErrorOutageCacheItem:', 'struct PumpChangeHistoryEntry:')
json_models = section('LoopFollow/Controllers/NightscoutCache.swift', 'struct SGVJSON:', '// One day’s payload')
treatment = read('LoopFollow/Views/Treatments/Models/Treatment.swift')
loader = read('LoopFollow/Views/Glucose/SensorErrors/GlucoseView+SensorLoading.swift')
daily = section('LoopFollow/Views/SensorHistoryView.swift', '    private func perCalendarDayErrorMinutes(', '    private func buildSensorErrorMessage(').replace('private func', 'func')
stubs = r'''
import Foundation
struct NightscoutUtils {
    static func parseDate(_ raw: String) -> Date? { TreatmentJSON.parseTrioSentAt(raw) }
}
class Storage {
    static let shared = Storage()
    var dexcomSensorErrorOutagesCache: [DexcomSensorErrorOutageCacheItem] = []
    var dexcomSensorErrorOutagesRefreshedAt: Date?
}
struct NightscoutCache {
    static var notes: [TreatmentJSON] = []
    static var readings: [SGVJSON] = []
    static func loadWindow(from start: Date, to end: Date) async -> ([SGVJSON], [TreatmentJSON]) {
        (readings.filter { $0.readingDate >= start && $0.readingDate <= end }, notes.filter { $0.created_at >= start && $0.created_at <= end })
    }
}
class Table { func reloadData() {} }
class Label { var text = "" }
class GlucoseView {
    enum Mode { case sensorErrors, allValues }
    enum GlucoseRow { case sensorError(date: Date, durationMinutes: Int?, note: Treatment) }
    var dataMode: Mode = .sensorErrors
    var sensorErrorRows: [GlucoseRow] = []
    let sensorErrorLookbackDays = 91
    let tableView = Table()
    let statsLabel = Label()
    func hideRefreshIndicator() {}
    func updateStatsLabel() {}
}
'''
checks = r'''
@main struct Check {
    static func main() async {
        let base = Date(timeIntervalSince1970: floor(Date().timeIntervalSince1970) - 89 * 86400)
        func note(_ seconds: Double, type: String = "Note", glucose: Any? = nil, units: String = "mg/dl") -> TreatmentJSON {
            var raw: [String: Any] = ["_id": "test-\(seconds)-\(type)", "created_at": ISO8601DateFormatter().string(from: base.addingTimeInterval(seconds)), "eventType": type, "notes": "Dexcom sensorfel", "enteredBy": "Trio", "units": units]
            if let glucose { raw["glucose"] = glucose }
            return TreatmentJSON(dict: raw)!
        }
        func reading(_ seconds: Double, _ value: Int = 100) -> SGVJSON {
            SGVJSON(date: base.addingTimeInterval(seconds).timeIntervalSince1970, sgv: value)
        }
        func build(_ readings: [SGVJSON], _ notes: [TreatmentJSON]) -> [DexcomSensorErrorOutageCacheItem] {
            DexcomSensorErrorOutageCacheItem.build(readings: readings, treatments: notes, now: Date())
        }
        let error = note(0)
        let recovered = build([reading(1200)], [error, note(900)])
        precondition(recovered.count == 1 && recovered[0].durationMinutes == 20)
        precondition(recovered[0].startTimestamp == base.timeIntervalSince1970)
        precondition(build([reading(-300), reading(1200)], [error])[0].durationMinutes == 20)
        let checks = [note(300, type: "BG Check", glucose: "5,6", units: "mmol"), error, note(900)]
        let manual = build([reading(310, 101), reading(1200)], checks)
        precondition(manual.count == 1 && manual[0].durationMinutes == 20, "Fingerstick must neither end nor split the outage")
        precondition(build([reading(310, 150), reading(1200)], checks)[0].durationMinutes == 5,
                     "A different CGM value near a BG Check must remain a recovery candidate")
        let mgdl = build([reading(300, 100), reading(1200)], [error, note(300, type: "BG Check", glucose: 100)])
        precondition(mgdl[0].durationMinutes == 20)
        let timestampOnly = build([reading(300), reading(1200)], [error, note(300, type: "BG Check")])
        precondition(timestampOnly[0].durationMinutes == 20)
        let ongoing = build([reading(310, 101)], checks)
        precondition(ongoing.count == 1 && ongoing[0].durationMinutes == nil)
        let separate = build([reading(1200), reading(2400)], [error, note(900), note(1800)])
        precondition(separate.count == 2 && separate.map { $0.durationMinutes! } == [10, 20])
        precondition(build([reading(4840 * 60)], [error])[0].durationMinutes == 4840,
                     "User-defined duration needs no preceding SGV or arbitrary duration cap")

        // Full-window repair removes obsolete repeated-note rows and recalculates old durations.
        NightscoutCache.notes = checks
        NightscoutCache.readings = [reading(310, 101), reading(1200)]
        Storage.shared.dexcomSensorErrorOutagesCache = [0.0, 900.0].map {
            DexcomSensorErrorOutageCacheItem(noteTimestamp: base.timeIntervalSince1970 + $0,
                startTimestamp: base.timeIntervalSince1970 - 300, endTimestamp: base.timeIntervalSince1970 + 1200,
                durationIsKnown: true)
        }
        Storage.shared.dexcomSensorErrorOutagesRefreshedAt = Date()
        let view = GlucoseView()
        await view.loadSensorErrors90Days()
        precondition(Storage.shared.dexcomSensorErrorOutagesCache.count == 1)
        precondition(Storage.shared.dexcomSensorErrorOutagesCache[0].durationMinutes == 20)
        if case let .sensorError(_, minutes, treatment) = view.sensorErrorRows[0] {
            precondition(minutes == 20 && treatment.rawData["enteredBy"] as? String == "Trio")
        }
        NightscoutCache.notes = []
        await view.loadSensorErrors90Days()
        precondition(Storage.shared.dexcomSensorErrorOutagesCache.count == 1, "Missing source must not erase history")

        let dayStart = Calendar.current.startOfDay(for: base)
        let nextDay = Calendar.current.date(byAdding: .day, value: 1, to: dayStart)!
        let days = [0, 1].map { _ in
            DexcomSensorErrorOutageCacheItem(noteTimestamp: dayStart.timeIntervalSince1970,
                startTimestamp: dayStart.timeIntervalSince1970, endTimestamp: nextDay.timeIntervalSince1970,
                durationIsKnown: true, calculationVersion: 3)
        }
        let daily = view.perCalendarDayErrorMinutes(outages: days, sessionStart: dayStart, sessionEnd: nextDay)
        precondition(daily[0] == Int(nextDay.timeIntervalSince(dayStart) / 60))
        let legacy = try! JSONDecoder().decode(DexcomSensorErrorOutageCacheItem.self,
            from: Data(#"{"noteTimestamp":100,"startTimestamp":0,"endTimestamp":290400,"durationIsKnown":true}"#.utf8))
        precondition(legacy.durationMinutes == nil)
        let roundtrip = try! JSONDecoder().decode([DexcomSensorErrorOutageCacheItem].self,
            from: JSONEncoder().encode(recovered))
        precondition(roundtrip == recovered)
        print("Sensor note/recovery, fingerstick, grouping, migration and overlap regressions passed")
    }
}
'''
source = stubs + json_models + model + treatment + loader + '\nextension GlucoseView {\n' + daily + '\n}\n' + checks
source = source.replace('import UIKit', '').replace('import Charts', '')
with tempfile.TemporaryDirectory(prefix='sensor-recovery-') as tmp:
    tmp = Path(tmp); swift = tmp / 'checks.swift'; swift.write_text(source)
    subprocess.run(['xcrun', 'swiftc', '-swift-version', '5', '-parse-as-library', '-module-cache-path', str(tmp / 'modules'), str(swift), '-o', str(tmp / 'checks')], check=True)
    subprocess.run([str(tmp / 'checks')], check=True)
