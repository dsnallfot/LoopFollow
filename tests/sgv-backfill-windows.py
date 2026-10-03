#!/usr/bin/env python3
"""Exercise production SGV fetching against a server with a response limit."""
from pathlib import Path
import subprocess
import tempfile
root = Path(__file__).resolve().parents[1]
s = (root / 'LoopFollow/Helpers/NightscoutUtils.swift').read_text()
a = s.index('    static func fetchSGVWindow(')
b = s.index('    /// Fetch all treatments', a)
methods = s[a:b]
stubs = r'''
import Foundation
struct SGVJSON { var date: Double; var sgv: Int; var trioSentAt: Date? }
struct ShareGlucoseData: Codable { var date: Double; var sgv: Int; var trioSentAt: Date? }
class LogManager {
    static let shared = LogManager()
    enum Category { case nightscout }
    func log(category: Category, message: String, isDebug: Bool) {}
}
struct NightscoutUtils {
    enum EventType { case sgv }
    static var requests = 0
    static func executeRequest(eventType: EventType, parameters: [String: String],
                               completion: (Result<[ShareGlucoseData], Error>) -> Void) {
        requests += 1
        let iso = ISO8601DateFormatter()
        let start = iso.date(from: parameters["find[dateString][$gte]"]!)!.timeIntervalSince1970
        let end = iso.date(from: parameters["find[dateString][$lte]"]!)!.timeIntervalSince1970
        precondition(end - start <= 86400)
        precondition(Int(parameters["count"]!)! <= 300)
        // Like a newest-first server response capped at 500 records.
        let rows = stride(from: end, through: start, by: -300).prefix(500).map {
            ShareGlucoseData(date: $0 * 1000, sgv: 100, trioSentAt: nil)
        }
        completion(.success(Array(rows)))
    }
'''
checks = r'''
}
@main struct Check {
    static func main() async {
        let start = Date(timeIntervalSince1970: 1_750_000_200)
        let end = start.addingTimeInterval(91 * 86400)
        let rows = await NightscoutUtils.fetchSGVWindow(from: start, to: end)
        precondition(NightscoutUtils.requests == 91)
        precondition(rows.count == 91 * 288 + 1)
        precondition(rows.first!.date == start.timeIntervalSince1970 && rows.last!.date == end.timeIntervalSince1970)
        precondition(Set(rows.map(\.date)).count == rows.count, "Boundary records must be deduplicated")
        let empty = await NightscoutUtils.fetchSGVWindow(from: end, to: start)
        precondition(empty.isEmpty)
        print("SGV daily backfill regressions passed")
    }
}
'''
with tempfile.TemporaryDirectory(prefix='sgv-backfill-') as tmp:
    tmp = Path(tmp)
    path = tmp / 'checks.swift'
    path.write_text(stubs + methods + checks)
    subprocess.run(['xcrun', 'swiftc', '-swift-version', '5', '-parse-as-library', '-module-cache-path', str(tmp / 'modules'), str(path), '-o', str(tmp / 'checks')], check=True)
    subprocess.run([str(tmp / 'checks')], check=True)
