#!/usr/bin/env python3
"""Exercise production filtering and duplicate navigation with a table bounds spy.
Run: python3 tests/treatment-duplicate-navigation.py (macOS + Swift).
"""
from pathlib import Path
import os
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
folder = root / 'LoopFollow/Views/Treatments'
sections = (folder / 'TreatmentsTableView+DaySections.swift').read_text()
filtering = sections[sections.index('    var filteredDaySections:'):sections.index('    var filteredTreatments:')]
refresh = (folder / 'TreatmentsTableView+Refresh.swift').read_text()
navigation = refresh[refresh.index('    private func firstDuplicateIndexPath()'):refresh.index('    // MARK: - Refresh Button Action')]
navigation = navigation.replace('@objc private func', 'func').replace('private func', 'func')
swift = r'''
import Foundation
extension IndexPath {
    init(row: Int, section: Int) { self.init(indexes: [section, row]) }
    var section: Int { self[0] }
    var row: Int { self[1] }
}
struct Treatment {
    let timestamp: Date
    let eventType: String
    var rawData: [String: Any] = [:]
}
class Segment { var selectedSegmentIndex = 0 }
class TableSpy {
    enum Position { case middle }
    var rows: [Int] = []
    var destination: IndexPath?
    var numberOfSections: Int { rows.count }
    func numberOfRows(inSection section: Int) -> Int { rows[section] }
    func scrollToRow(at path: IndexPath, at position: Position, animated: Bool) {
        precondition(path.section < rows.count && path.row < rows[path.section], "Invalid scroll destination")
        destination = path
    }
}
class TreatmentsTableView {
    struct TreatmentDaySection { let date: Date; var treatments: [Treatment] }
    var daySections: [TreatmentDaySection] = []
    var searchSections: [TreatmentDaySection] = []
    var isCategorySearchActive = false
    let segmentedControl = Segment()
    let tableView = TableSpy()
'''
# Use the production filter categories too.
controller = (folder / 'TreatmentsTableView.swift').read_text()
for line in controller.splitlines():
    if line.strip().startswith(('let autoTypes =', 'let manualTypes =')):
        swift += line + '\n'
swift += filtering + navigation + '\n}\n' + r'''
func treatment(_ time: Double, _ type: String, food: String = "") -> Treatment {
    Treatment(timestamp: Date(timeIntervalSince1970: time), eventType: type, rawData: ["foodType": food])
}
func section(_ rows: [Treatment]) -> TreatmentsTableView.TreatmentDaySection {
    .init(date: rows.first?.timestamp ?? Date(), treatments: rows)
}
let view = TreatmentsTableView()
func expect(_ expected: IndexPath?, _ message: String) {
    view.tableView.rows = view.filteredDaySections.map { $0.treatments.count }
    view.tableView.destination = nil
    precondition(view.firstDuplicateIndexPath() == expected, message)
    view.duplicateIndicatorTapped()
    precondition(view.tableView.destination == expected, message + " (tap)")
}
for (filter, type) in [(0, "Bolus"), (1, "SMB"), (2, "Carb Correction"), (3, "Sensor Start")] {
    view.segmentedControl.selectedSegmentIndex = filter
    let pair = treatment(100, type, food: "meal")
    view.daySections = [section([treatment(300, type, food: "meal")]),
                        section([treatment(200, type, food: "meal"), pair, pair])]
    expect(IndexPath(row: 1, section: 1), "Older day with nonzero row, filter \(filter)")
    // An unfiltered day index must not leak into the displayed section index.
    view.daySections.insert(section([treatment(400, "Note")]), at: 0)
    expect(IndexPath(row: 1, section: filter == 0 || filter == 3 ? 2 : 1), "Hidden newer day")
    view.daySections = [section([pair, pair]), section([pair, pair])]
    expect(IndexPath(row: 0, section: 0), "First duplicate wins in display order")
    view.daySections = [section([pair])]
    expect(nil, "Duplicate removed before tap")
}
view.segmentedControl.selectedSegmentIndex = 0
view.daySections = [section([treatment(100, "Note"), treatment(100, "Note"),
                             treatment(100, "Bolus"), treatment(100, "SMB"), treatment(101, "Bolus")])]
expect(nil, "Notes excluded; event type and exact timestamp must both match")
view.daySections = []
expect(nil, "Empty history")
view.segmentedControl.selectedSegmentIndex = 2
view.daySections = [section([treatment(100, "Carb Correction", food: "meal"), treatment(100, "Carb Correction")])]
expect(nil, "Manual filter excludes carb corrections without food")
view.segmentedControl.selectedSegmentIndex = 0
expect(IndexPath(row: 0, section: 0), "All includes both carb corrections")
view.tableView.rows = []
view.tableView.destination = nil
view.duplicateIndicatorTapped()
precondition(view.tableView.destination == nil, "Ignore stale table bounds")
// A submitted search owns an already-filtered snapshot, independent of browsing days.
view.isCategorySearchActive = true
view.segmentedControl.selectedSegmentIndex = 2
let searched = treatment(10, "Sensor Start")
view.searchSections = [section([searched, searched])]
expect(IndexPath(row: 0, section: 0), "Search snapshot supplies table and duplicate destination")
view.searchSections = []
expect(nil, "Empty search must not fall back to normal browsing rows")
view.isCategorySearchActive = false
print("Treatment duplicate navigation passed: all four filters, older days, hidden sections, deletion, notes and stale bounds")
'''
with tempfile.TemporaryDirectory(prefix='treatment-duplicates-') as directory:
    script = Path(directory) / 'main.swift'
    script.write_text(swift)
    env = dict(os.environ, CLANG_MODULE_CACHE_PATH=directory + '/modules')
    subprocess.run(['swift', str(script)], check=True, env=env)
