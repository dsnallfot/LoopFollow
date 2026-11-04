"""Run production treatment counting and period calculations against an in-memory cache."""
from pathlib import Path
import os
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
model = (root / 'LoopFollow/Stats/SimpleStatsViewModel.swift').read_text()
service = (root / 'LoopFollow/Stats/StatsHelpers/StatsDataService.swift').read_text()
count_method = service.split('    func getPumpCommandCount', 1)[1].split('    func getSMBData', 1)[0]
calculate_method = model.split('    private func calculatePumpCommandStatistics', 1)[1].split('    private func calculateSMBStatistics', 1)[0]
classification = model[model.index('struct PumpCommandStatistics {'):]
trend = (root / 'LoopFollow/Stats/StatsHelpers/StatsTrendCalculator.swift').read_text()
harness = '''
import Foundation
struct Treatment {
    let _id: String
    let created_at: Date
    let eventType: String
    let insulin: Double?
}
enum Missing: Error { case day }
struct NightscoutCache {
    static var days: [Date: [Treatment]] = [:]
    static func readTreatmentsForSearch(_ day: Date) throws -> [Treatment] {
        guard let treatments = days[day] else { throw Missing.day }
        return treatments
    }
}
class Source {
    var isTodayOnly = false
    func getPumpCommandCount
''' + count_method + '''
}
class Model {
    let dataService = Source()
    var pumpCommandsPerDay: Double?, prevPumpCommandsPerDay: Double?
    var pumpCommandsPerDayTrend: StatsTrendArrow = .none
    func calculatePumpCommandStatistics
''' + calculate_method + '\n}\n' + classification + '\n' + trend + '''
for type in ["Bolus", "Meal Bolus", "Correction Bolus", "SMB"] {
    assert(PumpCommandStatistics.isCommand(eventType: type, insulin: 0.1))
    for dose: Double? in [nil, 0, -1, .infinity, .nan] {
        assert(!PumpCommandStatistics.isCommand(eventType: type, insulin: dose))
    }
}
assert(PumpCommandStatistics.isCommand(eventType: "Temp Basal", insulin: nil))
for type in ["External Insulin", "Carb Correction", "Note", "BG Check"] {
    assert(!PumpCommandStatistics.isCommand(eventType: type, insulin: 1))
}
let calendar = Calendar.current
let start = calendar.date(from: DateComponents(year: 2026, month: 10, day: 22))!
let model = Model()
for days in [1, 2, 3, 7, 14, 30, 90] {
    NightscoutCache.days = [:]
    for offset in -days..<days {
        let day = calendar.date(byAdding: .day, value: offset, to: start)!
        let entries = [
            Treatment(_id: "basal-\\(offset)", created_at: day, eventType: "Temp Basal", insulin: nil),
            Treatment(_id: "bolus-\\(offset)", created_at: day.addingTimeInterval(60), eventType: "Bolus", insulin: 1),
            Treatment(_id: "smb-\\(offset)", created_at: day.addingTimeInterval(60), eventType: "SMB", insulin: 0.1)
        ]
        NightscoutCache.days[day] = entries + [entries[0]] // Duplicate ID must not count twice.
    }
    let end = calendar.date(byAdding: .day, value: days, to: start)!
    let interval = DateInterval(start: start, end: end)
    model.calculatePumpCommandStatistics(in: interval)
    assert(model.pumpCommandsPerDay == 3 && model.prevPumpCommandsPerDay == 3)
    assert(model.pumpCommandsPerDayTrend == .flat)
    NightscoutCache.days[start] = []
    model.calculatePumpCommandStatistics(in: interval)
    assert(abs(model.pumpCommandsPerDay! - Double((days - 1) * 3) / Double(days)) < 1e-9)
    NightscoutCache.days[start] = nil
    model.calculatePumpCommandStatistics(in: interval)
    assert(model.pumpCommandsPerDay == nil && model.pumpCommandsPerDayTrend == .none)
}
model.dataService.isTodayOnly = true
let yesterday = calendar.date(byAdding: .day, value: -1, to: start)!
for day in [start, yesterday] {
    NightscoutCache.days[day] = [
        Treatment(_id: "start-\\(day)", created_at: day, eventType: "Temp Basal", insulin: nil),
        Treatment(_id: "end-\\(day)", created_at: day.addingTimeInterval(3600), eventType: "Bolus", insulin: 2)
    ]
}
model.calculatePumpCommandStatistics(in: DateInterval(start: start, end: start.addingTimeInterval(3600)))
assert(model.pumpCommandsPerDay == 1 && model.prevPumpCommandsPerDay == 1)
print("Pump command tests passed: treatment types, duplicate IDs, periods, DST, boundaries, today, missing and empty days")
'''
with tempfile.TemporaryDirectory() as directory:
    path = Path(directory) / 'main.swift'
    path.write_text(harness)
    subprocess.run(['swiftc', '-module-cache-path', directory + '/cache', str(path), '-o', directory + '/test'], check=True)
    subprocess.run([directory + '/test'], env={**os.environ, 'TZ': 'Europe/Stockholm'}, check=True)
