"""Exercise the production SMB calculation with an in-memory data source."""
from pathlib import Path
import os
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
source = (root / 'LoopFollow/Stats/SimpleStatsViewModel.swift').read_text()
method = source.split('    private func calculateSMBStatistics', 1)[1].split('    private func calculateTotalBasal', 1)[0]
statistics = source[source.index('struct SMBStatistics {'):]
trend = (root / 'LoopFollow/Stats/StatsHelpers/StatsTrendCalculator.swift').read_text()
harness = '''
import Foundation
struct Entry { let date: Double; let value: Double }
class Source {
    var isTodayOnly = false
    var entries: [Entry] = []
    func getSMBData(in interval: DateInterval) -> [Entry] {
        entries.filter { $0.date >= interval.start.timeIntervalSince1970 && $0.date <= interval.end.timeIntervalSince1970 }
    }
}
class Model {
    let dataService = Source()
    var smbCountPerDay: Double?, meanSMB: Double?, prevSMBCountPerDay: Double?, prevMeanSMB: Double?
    var smbCountPerDayTrend: StatsTrendArrow = .none
    var meanSMBTrend: StatsTrendArrow = .none
    func calculateSMBStatistics
''' + method + '\n}\n' + statistics + '\n' + trend + '''
var calendar = Calendar.current
func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
    calendar.date(from: DateComponents(year: year, month: month, day: day))!
}
let model = Model()
for days in [1, 2, 3, 7, 14, 30, 90] {
    let start = date(2026, 10, 22)
    let end = calendar.date(byAdding: .day, value: days, to: start)!
    let previousStart = calendar.date(byAdding: .day, value: -days, to: start)!
    model.dataService.entries = [
        Entry(date: previousStart.timeIntervalSince1970, value: 0.1),
        Entry(date: start.timeIntervalSince1970, value: 0.2),
        Entry(date: start.addingTimeInterval(60).timeIntervalSince1970, value: 0.4),
        Entry(date: end.timeIntervalSince1970, value: 10)
    ]
    model.calculateSMBStatistics(in: DateInterval(start: start, end: end))
    assert(abs(model.smbCountPerDay! - 2.0 / Double(days)) < 1e-9)
    assert(abs(model.meanSMB! - 0.3) < 1e-9)
    assert(abs(model.prevSMBCountPerDay! - 1.0 / Double(days)) < 1e-9)
    assert(model.prevMeanSMB == 0.1)
    assert(model.meanSMBTrend == .strongUp)
}
model.dataService.isTodayOnly = true
let start = date(2026, 11, 3)
let yesterday = calendar.date(byAdding: .day, value: -1, to: start)!
model.dataService.entries = [
    Entry(date: yesterday.addingTimeInterval(3600).timeIntervalSince1970, value: 0.2),
    Entry(date: yesterday.addingTimeInterval(7200).timeIntervalSince1970, value: 9),
    Entry(date: start.addingTimeInterval(3600).timeIntervalSince1970, value: 0.4)
]
model.calculateSMBStatistics(in: DateInterval(start: start, end: start.addingTimeInterval(7200)))
assert(model.smbCountPerDay == 1 && model.prevSMBCountPerDay == 1)
assert(model.meanSMB == 0.4 && model.prevMeanSMB == 0.2)
model.dataService.entries = []
model.calculateSMBStatistics(in: DateInterval(start: start, end: start.addingTimeInterval(7200)))
assert(model.smbCountPerDay == 0 && model.meanSMB == nil)
assert(model.prevSMBCountPerDay == 0 && model.prevMeanSMB == nil)
assert(model.meanSMBTrend == .none)
let invalid = SMBStatistics(doses: [0, -1, .infinity, .nan, 0.5], days: 7)
assert(invalid.countPerDay == 1.0 / 7 && invalid.meanDose == 0.5)
print("SMB statistics passed: periods, DST, boundaries, today, empty and invalid doses")
'''
with tempfile.TemporaryDirectory() as directory:
    path = Path(directory) / 'main.swift'
    path.write_text(harness)
    subprocess.run(['swiftc', '-module-cache-path', directory + '/cache', str(path), '-o', directory + '/test'], check=True)
    subprocess.run([directory + '/test'], env={**os.environ, 'TZ': 'Europe/Stockholm'}, check=True)
