#!/usr/bin/env python3
"""Exercise production date parsers, thread ownership and formatter-free UI lookups."""
from pathlib import Path
import subprocess
import tempfile
root = Path(__file__).resolve().parents[1]
source = (root / 'LoopFollow/Helpers/NightscoutUtils.swift').read_text()
parsers = source[source.index('    private final class DateParsers'):source.index('    static func retrieveJWTToken')]
fixture = '''import Foundation
final class LogManager {
    static let shared = LogManager()
    enum Category { case nightscout }
    func log(category: Category, message: String, isDebug: Bool) {}
}
class NightscoutUtils {
'''+parsers+'''
    static func identity() -> ObjectIdentifier { ObjectIdentifier(dateParsers) }
}
'''
checks = r'''
// A prepared UI batch must never instantiate or consult a formatter, even for invalid/missing input.
let key = "LoopFollow.NightscoutUtils.DateParsers"
precondition(Thread.current.threadDictionary[key] == nil)
let prepared = ["1970-01-01T00:00:01Z": Date(timeIntervalSince1970: 1)]
precondition(NightscoutUtils.parseDate("1970-01-01T00:00:01Z", prepared: prepared) == Date(timeIntervalSince1970: 1))
precondition(NightscoutUtils.parseDate("1970-01-01T00:00:02Z", prepared: prepared) == nil)
precondition(NightscoutUtils.parseDate("invalid", prepared: prepared) == nil)
precondition(Thread.current.threadDictionary[key] == nil)

let group = DispatchGroup()
for _ in 0..<8 {
    group.enter()
    Thread.detachNewThread {
        let identity = NightscoutUtils.identity()
        for _ in 0..<500 {
            precondition(NightscoutUtils.identity() == identity, "Reuse the same thread-owned parsers")
            precondition(NightscoutUtils.parseDate("1970-01-01T00:00:01.250Z") == Date(timeIntervalSince1970: 1))
            precondition(NightscoutUtils.parseDate("1970-01-01T00:00:01") == Date(timeIntervalSince1970: 1))
            // Preserve historical treatment offset handling; do not shift existing graphs in this patch.
            precondition(NightscoutUtils.parseDate("1970-01-01T00:00:01+02:00") == Date(timeIntervalSince1970: 1))
            let fractional = NightscoutUtils.parseISODate("1970-01-01T00:00:01.250Z")!
            precondition(abs(fractional.timeIntervalSince1970 - 1.25) < 0.001)
            precondition(NightscoutUtils.parseISODate("1970-01-01T02:00:01.250+02:00") == fractional)
            precondition(NightscoutUtils.parseISODate("1970-01-01T00:00:01Z") == Date(timeIntervalSince1970: 1))
            precondition(NightscoutUtils.parseISODate("invalid") == nil)
        }
        group.leave()
    }
}
precondition(group.wait(timeout: .now() + 30) == .success, "Concurrent parsing must finish")
precondition(Thread.current.threadDictionary[key] == nil, "Workers must not create UI-thread formatters")
print("PASS: concurrent parser reuse, legacy timestamps, precise ISO offsets/fractions and formatter-free UI batch lookups")
'''
with tempfile.TemporaryDirectory(prefix='lf-date-parser-') as directory:
    p = Path(directory)
    (p/'test.swift').write_text(fixture+checks)
    subprocess.run(['xcrun','swiftc','-module-cache-path',str(p/'modules'),str(p/'test.swift'),'-o',str(p/'tests')],check=True)
    subprocess.run([str(p/'tests')],check=True,timeout=40)
