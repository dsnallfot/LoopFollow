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
struct Reading { var date: TimeInterval }
struct Note { var date: TimeInterval; var note: String }
class MainViewController {
    var bgData: [Reading] = []
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
print("Sensor status regressions passed")
'''
with tempfile.TemporaryDirectory(prefix='sensor-status-') as directory:
    path = Path(directory) / 'main.swift'
    path.write_text(status_source(repo) + stubs + '\nextension MainViewController {\n' + functions + '\n}\n' + checks)
    subprocess.run(['swift', '-module-cache-path', directory + '/module-cache', str(path)], check=True)
