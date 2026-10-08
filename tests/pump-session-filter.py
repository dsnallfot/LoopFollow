#!/usr/bin/env python3
"""Exercise pump filtering and session duration using production model/helpers."""
from pathlib import Path
import subprocess
import tempfile

repo = Path(__file__).resolve().parents[1]
source = (repo / 'LoopFollow/Views/PumpHistoryView.swift').read_text()
helpers = source[source.index('struct PumpSessionBuckets'):source.index('class PumpHistoryViewController')]
model_source = (repo / 'LoopFollow/Storage/Storage.swift').read_text()
start = model_source.index('struct PumpChangeHistoryEntry:')
end = model_source.index('\n}\n', start) + 3
model = model_source[start:end]
checks = r'''
let old = PumpChangeHistoryEntry(date: 0)
precondition(PumpSessionFilter.omnipod.includes(old))
precondition(!PumpSessionFilter.medtrum.includes(old))
let mixedCase = PumpChangeHistoryEntry(date: 0, pumpModel: "mEdTrUm Nano")
precondition(PumpSessionFilter.medtrum.includes(mixedCase))
precondition(!PumpSessionFilter.omnipod.includes(mixedCase))
let failure = PumpChangeHistoryEntry(date: 0, notes: "Kritiskt poddfel", pumpModel: "Omnipod DASH")
precondition(PumpSessionFilter.omnipod.includes(failure))
let decoded = try JSONDecoder().decode(PumpChangeHistoryEntry.self, from: Data("{\"date\":0}".utf8))
precondition(PumpSessionFilter.omnipod.includes(decoded))
let history = [
    PumpChangeHistoryEntry(date: 200 * 3600, pumpModel: "Medtrum"),
    PumpChangeHistoryEntry(date: 150 * 3600, pumpModel: "Omnipod"),
    PumpChangeHistoryEntry(date: 90 * 3600, pumpModel: "Medtrum"),
    PumpChangeHistoryEntry(date: 0)
]
let all = PumpSessionBuckets.compute(from: history)
let omni = PumpSessionBuckets.compute(from: history, filter: .omnipod)
let med = PumpSessionBuckets.compute(from: history, filter: .medtrum)
precondition(all.total == 3 && all.hrs_total == 190)
// The intervening Medtrum start must still end the older Omnipod session.
precondition(omni.total == 2 && omni.hrs_total == 130)
precondition(med.total == 1 && med.hrs_total == 60)
precondition(PumpSessionBuckets.compute(from: [mixedCase], filter: .medtrum).total == 0)
precondition(PumpSessionBuckets.compute(from: [failure, old], filter: .medtrum).total == 0)
precondition(PumpSessionBuckets.compute(from: []).total == 0)
precondition(PumpSessionFilter.all.pumpsTitle == "Alla pumpar")
precondition(PumpSessionFilter.omnipod.pumpsTitle == "Omnipod pumpar")
precondition(PumpSessionFilter.medtrum.pumpsTitle == "Medtrum pumpar")
print("Pump session filter regressions passed")
'''
with tempfile.TemporaryDirectory(prefix='pump-filter-') as directory:
    path = Path(directory) / 'main.swift'
    path.write_text('import Foundation\n' + model + helpers + checks)
    subprocess.run(['swift', '-module-cache-path', directory + '/module-cache', str(path)], check=True)
