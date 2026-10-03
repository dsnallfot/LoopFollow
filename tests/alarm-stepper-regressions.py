#!/usr/bin/env python3
"""Run the production stepper conversion without an iOS simulator."""
from pathlib import Path
import os
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
source = (root / 'LoopFollow/Helpers/AlarmUIComponents.swift').read_text()
scale = source.split('struct AlarmStepperScale {', 1)[1].split('// 2. Stepper Cell', 1)[0]
swift = 'import Foundation\nstruct AlarmStepperScale {' + scale + r'''
func close(_ actual: Double, _ expected: Double) {
    precondition(abs(actual - expected) < 0.00001, "Expected \(expected), got \(actual)")
}
let glucoseIDs = ["low_bg", "urgent_low_bg", "high_bg", "urgent_high_bg",
    "low_persistence_max", "fast_drop_delta", "fast_rise_delta",
    "fast_drop_below_bg", "fast_rise_above_bg", "temporary_bg",
    "not_looping_lower_limit", "not_looping_upper_limit", "missed_bolus_low_grams_bg"]
for id in glucoseIDs {
    let mmol = AlarmStepperScale(id: id, units: "mmol/L", minimum: 40, maximum: 150, step: 0.1)
    precondition(mmol.isGlucose && mmol.usesMmol)
    close(mmol.displayValue(forStoredValue: 70), 3.9)
    let plus = mmol.normalizedDisplayValue(3.9 + mmol.stepValue)
    close(plus, 4.0)
    close(mmol.storedValue(forDisplayValue: plus), 72.0728)
    close(mmol.normalizedDisplayValue(4.0 - mmol.stepValue), 3.9)
    close(mmol.displayValue(forStoredValue: Double(Float(mmol.storedValue(forDisplayValue: 3.9)))), 3.9)
    // Reopening after persistence must not require an extra tap or accumulate drift.
    var stored = 70.0
    for _ in 0..<10 {
        stored = Double(Float(mmol.storedValue(forDisplayValue: mmol.displayValue(forStoredValue: stored) + mmol.stepValue)))
    }
    close(mmol.displayValue(forStoredValue: stored), 4.9)
    for _ in 0..<10 {
        stored = Double(Float(mmol.storedValue(forDisplayValue: mmol.displayValue(forStoredValue: stored) - mmol.stepValue)))
    }
    close(mmol.displayValue(forStoredValue: stored), 3.9)
    precondition(mmol.storedValue(forDisplayValue: -100) >= 40)
    precondition(mmol.storedValue(forDisplayValue: 1000) <= 150)
    for units in ["mg/dL", ""] {
        let mg = AlarmStepperScale(id: id, units: units, minimum: 40, maximum: 150, step: 1)
        precondition(mg.isGlucose && !mg.usesMmol)
        close(mg.displayValue(forStoredValue: 70), 70)
        close(mg.storedValue(forDisplayValue: 70 + mg.stepValue), 71)
        close(mg.storedValue(forDisplayValue: 70 - mg.stepValue), 69)
    }
}
let delta = AlarmStepperScale(id: "low_persistence_max", units: "mmol/L", minimum: 0, maximum: 20, step: 1)
close(delta.storedValue(forDisplayValue: delta.stepValue), 1.80182)
for (id, value, step, maximum) in [("low_snooze", 5.0, 5.0, 30.0), ("iob_at", 0.9, 0.1, 10.0), ("forcedOutputVolume", 50.0, 5.0, 100.0)] {
    let scale = AlarmStepperScale(id: id, units: "mmol/L", minimum: 0, maximum: maximum, step: step)
    precondition(!scale.isGlucose && !scale.usesMmol)
    close(scale.displayValue(forStoredValue: value), value)
    close(scale.stepValue, step)
    close(scale.storedValue(forDisplayValue: value + step), value + step)
}
print("Alarm stepper regressions passed: mmol/L, mg/dL, persistence, limits and non-glucose settings")
'''
with tempfile.TemporaryDirectory(prefix='alarm-stepper-') as directory:
    script = Path(directory) / 'main.swift'
    script.write_text(swift)
    env = dict(os.environ, CLANG_MODULE_CACHE_PATH=str(Path(directory) / 'modules'))
    subprocess.run(['swift', str(script)], check=True, env=env)
