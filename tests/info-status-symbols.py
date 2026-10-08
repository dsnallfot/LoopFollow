#!/usr/bin/env python3
"""Verify generated status parsing, mapping, and preservation of unrelated text."""
from pathlib import Path
import subprocess
import tempfile
from info_status_support import status_source

repo = Path(__file__).resolve().parents[1]
checks = r'''
let expected: [(String, String, UIColor)] = [
    ("🔴", "circle.fill", .systemRed), ("🟡", "circle.fill", .systemYellow),
    ("🟢", "circle.fill", .systemGreen), ("🟣", "circle.fill", .systemPurple),
    ("🟠", "circle.fill", .systemOrange), ("🔵", "circle.fill", .systemBlue),
    ("⚠️", "exclamationmark.triangle.fill", .systemOrange),
    ("✅", "checkmark.circle.fill", .systemGreen),
    ("🚫", "exclamationmark.triangle.fill", .systemRed),
    ("⛔️", "exclamationmark.triangle.fill", .systemRed),
    ("🆘", "sos.circle.fill", .systemRed), ("⏱️", "clock.fill", .lightGray),
    ("🔺", "arrow.up", .systemBlue), ("🔻", "arrow.down", .systemRed),
    ("⚡", "bolt.fill", .systemYellow), ("⚫️", "circle.fill", .secondaryLabel),
    ("❌", "xmark.circle.fill", .systemRed), ("⭐️", "star.fill", .systemYellow)
]
for (emoji, name, color) in expected {
    let parsed = InfoStatusValue(legacyText: "12.3 E " + emoji)
    precondition(parsed.text == "12.3 E")
    precondition(parsed.symbol?.systemName == name, emoji)
    precondition(parsed.symbol?.color == color, emoji)
}
precondition(InfoStatusValue(legacyText: "Fel ⚠").symbol == .warning)
precondition(InfoStatusValue(legacyText: "Fel ⛔").symbol == .stop)
precondition(InfoStatusValue(legacyText: "50 % ⚡️ ").symbol == .charging)
precondition(InfoStatusValue(legacyText: "--").symbol == nil)
precondition(InfoStatusValue(legacyText: "Profil 🐻").text == "Profil 🐻")
precondition(InfoStatusValue(legacyText: "⚠️ note in middle").text == "⚠️ note in middle")
precondition(!InfoType.override.usesStatusSymbol && !InfoType.profile.usesStatusSymbol)
precondition(InfoType.allCases.filter { $0.usesStatusSymbol }.count == 22)
print("Info status symbol regressions passed: 18 mappings, 22 data types")
'''
with tempfile.TemporaryDirectory(prefix='info-status-') as directory:
    path = Path(directory) / 'main.swift'
    path.write_text(status_source(repo) + (repo / 'LoopFollow/InfoTable/InfoType.swift').read_text() + checks)
    subprocess.run(['swift', '-module-cache-path', directory + '/module-cache', str(path)], check=True)
