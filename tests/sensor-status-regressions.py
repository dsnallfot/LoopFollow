#!/usr/bin/env python3
"""Exercise the production sensor-status functions with a deterministic clock.
Run on macOS with Python 3 and Swift; no simulator or Nightscout required.
"""
from pathlib import Path
import subprocess
import tempfile

repo = Path(__file__).resolve().parents[1]
from info_status_support import status_source

source = (repo / 'LoopFollow/Controllers/Nightscout/BGData.swift').read_text()
start = source.index('    func updateSensorStatus(')
end = source.index('    /// Shows a big unicorn', start)
functions = source[start:end]
model_source = (repo / 'LoopFollow/Extensions/ShareClientExtension.swift').read_text()
model_source = model_source[model_source.index('public struct ShareGlucoseData:'):model_source.index('private var TrendTable:')]

stubs = r'''
import Foundation
enum InfoType: Int { case sensorStatus }
struct InfoData { var value = ""; var symbol: InfoStatusSymbol? }
class InfoManager {
    var tableData = [InfoData()]
    var priority = false
    var updates = 0
    func updateInfoData(type: InfoType, value: String) {
        let parsed = InfoStatusValue(legacyText: value)
        tableData[type.rawValue].value = parsed.text
        tableData[type.rawValue].symbol = parsed.symbol
        updates += 1
    }
    func setPriority(_ value: Bool, for type: InfoType) { priority = value }
}
typealias Reading = ShareGlucoseData
extension ShareGlucoseData {
    init(date: TimeInterval, id: String? = nil) {
        self.init(sgv: 100, date: date, direction: nil, nightscoutID: id)
    }
}
struct Note { var date: TimeInterval; var note: String }
class MainViewController {
    var bgData: [Reading] = []
    var fingerstickSGVIds: Set<String> = []
    var warningGraphData: [Note] = []
    let infoManager = InfoManager()
}
'''
checks = r'''
let controller = MainViewController()
func check(_ expected: String, _ priority: Bool, at time: TimeInterval) {
    controller.updateSensorStatus(now: time)
    let parsed = InfoStatusValue(legacyText: expected)
    precondition(controller.infoManager.tableData[0].value == parsed.text, expected)
    precondition(controller.infoManager.tableData[0].symbol == parsed.symbol, expected)
    precondition(controller.infoManager.priority == priority, "Incorrect priority for \(expected)")
}
check("--", false, at: 1000)
controller.bgData = [Reading(date: 1000)]
check("OK 🟢", false, at: 1359)
check("--", false, at: 1360)
// A treatment arriving after the stale BG refresh must take effect without a new BG.
controller.warningGraphData = [Note(date: 1300, note: "⚠️ Dexcom G7: sensor error")]
check("Fel ⚠️", true, at: 1361)
controller.warningGraphData.append(Note(date: 1310, note: "⛔️ Dexcom G7: sensor error"))
check("Fel ⛔️", true, at: 1362)
// Repeated minute ticks should not reload unchanged table data.
let updates = controller.infoManager.updates
check("Fel ⛔️", true, at: 1400)
precondition(controller.infoManager.updates == updates)
// Treatment removal clears both the warning and its priority immediately.
controller.warningGraphData = []
check("--", false, at: 1401)
// Receiving a warning before the six-minute boundary must be picked up by the timer.
controller.warningGraphData = [Note(date: 1300, note: "⚠️ Dexcom G7: sensor error")]
check("OK 🟢", false, at: 1359)
check("Fel ⚠️", true, at: 1360)
// Recovery: a newer BG clears the error; the old note cannot revive it later.
controller.bgData = [Reading(date: 1500)]
check("OK 🟢", false, at: 1500)
check("--", false, at: 1860)
// Notes at or before the latest BG, and unrelated newer warnings, are ignored.
controller.warningGraphData = [
    Note(date: 1500, note: "⛔️ Dexcom G7"),
    Note(date: 1499, note: "⚠️ Dexcom G7"),
    Note(date: 1600, note: "⚠️ Pump warning")
]
check("--", false, at: 1860)
controller.bgData = []
check("--", false, at: 1860)
// Reproduce the reported Trio fingerstick: treatment.id links to SGV._id.
let iso = ISO8601DateFormatter()
iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
let warningTime = iso.date(from: "2026-10-21T14:33:25.850Z")!.timeIntervalSince1970
let fingerstickJSON = #"{"_id":"422F8622-0573-40D8-AFC5-4412708624F8","sgv":73,"date":1792593357787.3528,"trioSentAt":"2026-10-21T14:36:09.227Z"}"#
var fingerstick = try! JSONDecoder().decode(ShareGlucoseData.self, from: Data(fingerstickJSON.utf8))
fingerstick.date /= 1000
precondition(fingerstick.nightscoutID == "422F8622-0573-40D8-AFC5-4412708624F8")
let treatment: [String: AnyObject] = [
    "_id": "6ad8cdd9945094b81041097f",
    "id": "422F8622-0573-40D8-AFC5-4412708624F8",
    "eventType": "BG Check", "glucoseType": "Fingerstick",
    "created_at": "2026-10-21T14:35:57.787Z",
    "glucose": 4.1, "units": "mmol"
].mapValues { $0 as AnyObject }
controller.warningGraphData = [Note(date: warningTime, note: "⚠️ Dexcom G7: Tillfälligt sensorfel!")]
controller.bgData = [Reading(date: warningTime - 300, id: "sensor"), fingerstick]
// BG can arrive before treatments; the later treatment refresh corrects the status.
check("OK 🟢", false, at: fingerstick.date + 10)
controller.updateFingerstickSGVIds(entries: [treatment])
check("Fel ⚠️", true, at: fingerstick.date + 10)
check("Fel ⚠️", true, at: fingerstick.date + 600)
precondition(controller.bgData.count == 2, "Fingerstick must remain in the graph data")
// Treatment-first arrival behaves identically.
controller.bgData.removeLast()
check("Fel ⚠️", true, at: fingerstick.date + 10)
controller.bgData.append(fingerstick)
check("Fel ⚠️", true, at: fingerstick.date + 10)
// A genuine sensor reading at the same time is not excluded by timestamp matching.
controller.bgData.append(Reading(date: fingerstick.date, id: "real-sensor"))
check("OK 🟢", false, at: fingerstick.date + 10)
check("--", false, at: fingerstick.date + 600)
controller.bgData.removeLast()
// Missing SGV IDs (e.g. Dexcom Share) remain eligible as sensor readings.
controller.bgData.append(Reading(date: fingerstick.date))
check("OK 🟢", false, at: fingerstick.date + 10)
controller.bgData.removeLast()
// Only explicitly identified fingerstick BG Checks qualify.
for field in ["eventType", "glucoseType", "id"] {
    var unrelated = treatment
    unrelated.removeValue(forKey: field)
    controller.updateFingerstickSGVIds(entries: [unrelated])
    precondition(controller.fingerstickSGVIds.isEmpty)
}
controller.updateFingerstickSGVIds(entries: [treatment])
controller.bgData = [fingerstick]
check("--", false, at: fingerstick.date + 10)
// A deleted treatment removes its old match on the next snapshot.
controller.updateFingerstickSGVIds(entries: [])
check("OK 🟢", false, at: fingerstick.date + 10)
print("Sensor status regressions passed")
'''
with tempfile.TemporaryDirectory(prefix='sensor-status-') as directory:
    path = Path(directory) / 'main.swift'
    path.write_text(status_source(repo) + model_source + stubs + '\nextension MainViewController {\n' + functions + '\n}\n' + checks)
    subprocess.run(['swift', '-module-cache-path', directory + '/module-cache', str(path)], check=True)
