#!/usr/bin/env python3
"""Verify the production sender and wire payload without sending notifications."""
from pathlib import Path
import subprocess
import tempfile
root = Path(__file__).resolve().parents[1]
manager = (root / 'LoopFollow/Remote/PushNotificationManager.swift').read_text()
start = manager.index('    func sendSnoozePushNotification(')
end = manager.index('    func sendOverridePushNotification(', start)
source = '''import Foundation
final class PushNotificationManager {
    let user = "parent"
    let sharedSecret = "test-secret"
    var sent: [PushMessage] = []
    func sendPushNotification(message: PushMessage, completion: @escaping (Bool, String?) -> Void) {
        sent.append(message)
        completion(true, nil)
    }
'''+manager[start:end]+'}\n'
for file in ['LoopFollow/Remote/TRC/TRCCommandType.swift', 'LoopFollow/Remote/PushMessage.swift',
             'LoopFollow/Remote/TRC/HealthLoggingRules.swift']:
    source += (root / file).read_text()
source += r'''
@main struct Tests {
    static func main() throws {
        let manager = PushNotificationManager()
        let options = HealthLoggingRules.snoozeMinutes
        precondition(options == [0, 15, 30, 45, 60, 75, 90, 105, 120, 135, 150, 165, 180, 240, 300, 360, 420, 480])
        precondition(HealthLoggingRules.snoozeLabel(0) == "Avbryt snooze")
        precondition(HealthLoggingRules.snoozeLabel(75) == "1 tim 15 min")
        for duration in [0, 1, 15, 180, 480] {
            let before = Date().timeIntervalSince1970
            manager.sendSnoozePushNotification(duration: duration) { ok, error in precondition(ok && error == nil) }
            let payload = try JSONSerialization.jsonObject(with: JSONEncoder().encode(manager.sent.last!)) as! [String: Any]
            precondition(payload["command_type"] as? String == "snooze")
            precondition(payload["duration"] as? Int == duration)
            precondition(payload["user"] as? String == "parent" && payload["shared_secret"] as? String == "test-secret")
            let timestamp = payload["timestamp"] as! Double
            precondition(timestamp >= before && timestamp <= Date().timeIntervalSince1970)
            precondition(payload["scheduled_time"] == nil, "Uses send time, never health log event time")
        }
        for duration in [-1, 481, Int.max] {
            manager.sendSnoozePushNotification(duration: duration) { ok, error in precondition(!ok && error != nil) }
        }
        precondition(manager.sent.count == 5, "Invalid durations never reach transport")
        print("PASS: snooze picker options, labels, sender validation, credentials, wire command and send-time timestamp")
    }
}
'''
with tempfile.TemporaryDirectory(prefix='lf-snooze-') as directory:
    path = Path(directory)
    (path / 'test.swift').write_text(source)
    subprocess.run(['xcrun', 'swiftc', '-module-cache-path', str(path / 'modules'), '-parse-as-library',
                    str(path / 'test.swift'), '-o', str(path / 'tests')], check=True)
    subprocess.run([str(path / 'tests')], check=True)
