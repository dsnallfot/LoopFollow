#!/usr/bin/env python3
"""Run production history refresh, row warning and alert code with a delayed cache read."""
from pathlib import Path
import subprocess
import tempfile

repo = Path(__file__).resolve().parents[1]
def section(path, start, end):
    source = (repo / path).read_text()
    begin = source.index(start)
    return source[begin:source.index(end, begin)]

view = 'LoopFollow/Views/SensorHistoryView.swift'
models = section('LoopFollow/Storage/Storage.swift', 'struct SensorStartHistoryEntry:', 'struct PumpChangeHistoryEntry:')
json_models = section('LoopFollow/Controllers/NightscoutCache.swift', 'struct SGVJSON:', '// One day’s payload')
methods = ''.join([
    section(view, '    private func sessionAppendInfo(', '    private func loadDexcomOutagesCacheAndRefreshIfNeeded'),
    section(view, '    private func refreshDexcomOutagesCacheIfNeeded', '    private func showSensorErrorAlert('),
    section(view, '    func tableView(_ tableView: UITableView, didSelectRowAt', '    // MARK: - Swipe to Edit/Delete'),
]).replace('private func', 'func')
stubs = r'''
import Foundation
struct LogManager {
    static let shared = LogManager()
    enum Category { case bluetooth }
    func log(category: Category, message: String) {}
}
struct NightscoutUtils {
    static func parseDate(_ raw: String) -> Date? { TreatmentJSON.parseTrioSentAt(raw) }
}
class Storage {
    static let shared = Storage()
    var sensorStartNotes: [SensorStartHistoryEntry] = []
    var dexcomSensorErrorOutagesCache: [DexcomSensorErrorOutageCacheItem] = []
    var dexcomSensorErrorOutagesRefreshedAt: Date?
}
@MainActor struct NightscoutCache {
    static var notes: [TreatmentJSON] = []
    static var readings: [SGVJSON] = []
    static var continuation: CheckedContinuation<Void, Never>?
    static var calls = 0
    static func loadWindow(from: Date, to: Date) async -> ([SGVJSON], [TreatmentJSON]) {
        calls += 1
        await withCheckedContinuation { continuation = $0 }
        return (readings, notes)
    }
}
enum UIColor { case label, systemBlue, systemGreen, systemOrange, systemRed }
class RefreshControl { func endRefreshing() {} }
class UITableView { var refreshControl: RefreshControl?; var reloads = 0; func reloadData() { reloads += 1 } }
extension IndexPath { var row: Int { self[0] } }
class View { var window: Int? = 1 }
@MainActor class Harness {
    var sensorHistory: [SensorStartHistoryEntry] = []
    var analysisDate = Date()
    var dexcomOutagesCache: [DexcomSensorErrorOutageCacheItem] = []
    var dexcomOutagesRefreshTask: Task<Void, Never>?
    var isPresentingSensorErrors = false
    var needsAnotherSensorRefresh = false
    var sourceTreatmentCount = 0
    func loadSensorHistory() { sensorHistory = Storage.shared.sensorStartNotes; tableView.reloadData() }
    let tableView = UITableView()
    var viewIfLoaded: View? = View()
    var presentedViewController: Int?
    var messages: [String] = []
    func currentHistory() -> [SensorStartHistoryEntry] { sensorHistory }
    func showSensorErrorAlert(indexPath: IndexPath, sensorName: String?, message: String, diagnosticMessage: String? = nil) { messages.append(message) }
'''
checks = r'''
@main struct Check {
    @MainActor static func main() async {
        // Fixed calendar positions make the expected daily split independent of run time.
        let end = Calendar.current.startOfDay(for: Date()).addingTimeInterval(-86400 + 18 * 3600)
        let start = end.addingTimeInterval(-30 * 3600)
        let entry = SensorStartHistoryEntry(date: start.timeIntervalSince1970, note: "ABC123")
        let view = Harness()
        // Persisted boundaries were corrected after the view took its snapshot.
        var staleEntry = entry
        staleEntry.trioSentAt = Date().addingTimeInterval(3600)
        view.sensorHistory = [staleEntry]
        Storage.shared.sensorStartNotes = [entry]
        view.analysisDate = start // Simulate a view created before the errors occurred.
        for (offset, minutes) in [(3600.0, 10), (25 * 3600.0, 5), (27 * 3600.0, 5)] {
            let time = start.addingTimeInterval(offset)
            NightscoutCache.notes.append(TreatmentJSON(dict: [
                "_id": "\(offset)", "created_at": ISO8601DateFormatter().string(from: time),
                "eventType": "Note", "notes": "Dexcom sensorfel"
            ])!)
            NightscoutCache.readings.append(SGVJSON(date: time.addingTimeInterval(Double(minutes * 60)).timeIntervalSince1970, sgv: 100))
        }
        view.refreshDexcomOutagesCacheIfNeeded()
        view.tableView(view.tableView, didSelectRowAt: IndexPath(index: 0))
        view.tableView(view.tableView, didSelectRowAt: IndexPath(index: 0))
        while NightscoutCache.continuation == nil { await Task.yield() }
        precondition(view.messages.isEmpty, "Must not show an empty alert while refresh is pending")
        precondition(NightscoutCache.calls == 1, "Taps must share the in-flight refresh")
        // A treatments-updated notification during a read must not be dropped.
        view.needsAnotherSensorRefresh = true
        let firstRead = NightscoutCache.continuation!
        NightscoutCache.continuation = nil
        firstRead.resume()
        while NightscoutCache.continuation == nil { await Task.yield() }
        precondition(view.messages.isEmpty, "Alert must wait for the queued refresh too")
        precondition(NightscoutCache.calls == 2)
        NightscoutCache.continuation!.resume()
        for _ in 0..<1000 {
            if !view.messages.isEmpty { break }
            try! await Task.sleep(nanoseconds: 1_000_000)
        }
        precondition(view.messages.count == 1, "Repeated taps must not present duplicate alerts")
        let message = view.messages[0]
        precondition(message.contains("3 st") && message.contains("20 min"))
        precondition(message.contains("Dag 1:   10 min") && message.contains("Dag 2:   10 min"))
        precondition(view.sessionAppendInfo(forEntry: entry).text.contains("⚠️"), "New errors must update the ongoing row warning")
        precondition(view.sensorHistory[0].trioSentAt == nil, "Refresh must replace stale session boundaries")
        precondition(view.tableView.reloads == 2)
        precondition(Storage.shared.sensorStartNotes[0].sensorErrors == nil, "Ongoing summaries must remain live")
        precondition(view.dexcomOutagesRefreshTask == nil)
        print("Sensor history delayed refresh, ongoing warning, 3 errors / 20 minutes and daily totals passed")
    }
}
'''
with tempfile.TemporaryDirectory(prefix='sensor-history-') as temp:
    temp = Path(temp)
    source = temp / 'checks.swift'
    source.write_text(stubs + methods + '\n}\n' + models + json_models + checks)
    subprocess.run(['xcrun', 'swiftc', '-swift-version', '5', '-parse-as-library', '-module-cache-path', str(temp / 'modules'), str(source), '-o', str(temp / 'checks')], check=True)
    subprocess.run([str(temp / 'checks')], check=True)
