#!/usr/bin/env python3
"""Exercise the production draft parser against existing and edited calendar formats."""
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
source = (root / 'LoopFollow/ViewControllers/WatchSettingsViewController.swift').read_text()
model = source[source.index('private enum CalendarLineVariable:'):source.index('private final class CalendarLineEditor:')]
renderer_source = (root / 'LoopFollow/ViewControllers/MainViewController.swift').read_text()
renderer = renderer_source[renderer_source.index('        let calendarValues:'):renderer_source.index('        // Delete Events from last 2 hours')]
checks = r'''
let examples = ["", "%BG% %DIRECTION% %DELTA% %MINAGO%", "%15MIN% • %IOB% • %COB%",
                "C:%COB% I:%IOB% B:%BASAL%", "💙 %BG%  •  %UNKNOWN%"]
for original in examples {
    precondition(CalendarLineDraft(original).value == original, "Opening and saving must preserve existing formats")
}
private var draft = CalendarLineDraft(examples[2])
precondition(draft.parts == ["%15MIN%", "•", "%IOB%", "•", "%COB%"])
precondition(CalendarLineVariable.display(draft.value) == "15Min • IOB • COB")
draft.modified = true
let moved = draft.parts.remove(at: 4)
draft.parts.insert(moved, at: 0)
precondition(draft.value == "%COB% %15MIN% • %IOB% •")
draft.parts.removeLast()
draft.parts.append("%BG%")
precondition(draft.value == "%COB% %15MIN% • %IOB% %BG%")
draft.parts.removeAll()
precondition(draft.value.isEmpty)
private let legacy = CalendarLineDraft(examples[3])
precondition(legacy.parts == ["C:", "%COB%", "I:", "%IOB%", "B:", "%BASAL%"])
private let unknown = CalendarLineDraft(examples[4])
precondition(unknown.parts == ["💙", "%BG%", "•", "%UNKNOWN%"])
let all = CalendarLineVariable.allCases.map(\.placeholder).joined(separator: " ")
precondition(CalendarLineDraft(all).parts.count == 10)
precondition(!CalendarLineVariable.display(all).contains("%"))
struct Amount {
    func formattedValue() -> String { "1" }
}
struct Renderer {
    let latestLoopStatusString = "LoopOK"
    func verify() {
        let bgDisplayUnits = "5.5", direction = "→", deltaStringWithoutCommas = "+0.1"
        let latestIOB: Amount? = Amount(), latestCOB: Amount? = Amount()
        let basal = "0.5", overrideText = "120%", minAgo = "12 min", fifteenMinText = "✅ 5.7"
        var eventTitle = all
        var eventLocation = all
        RENDERER
        precondition(eventTitle == "5.5 → +0.1 1 1 0.5 LoopOK 120% 12 min ✅ 5.7")
        precondition(eventLocation == eventTitle, "Every variable must resolve on both lines")
    }
}
Renderer().verify()
print("Calendar line draft and both-line rendering checks passed")
'''
with tempfile.TemporaryDirectory(prefix='calendar-lines-') as tmp:
    path = Path(tmp)
    (path / 'main.swift').write_text('import Foundation\n' + model + checks.replace('        RENDERER', renderer))
    subprocess.run(['xcrun', 'swiftc', '-module-cache-path', '/tmp/calendar-module-cache',
                    str(path / 'main.swift'), '-o', str(path / 'test')], check=True)
    subprocess.run([str(path / 'test')], check=True)
