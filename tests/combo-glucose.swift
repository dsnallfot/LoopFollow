import Foundation

// Compile with TRCCommandType.swift, PushMessage.swift and RemoteCommandReceiptTracker.swift.
@main
struct ComboGlucoseTests {
    static func main() throws {
        let sent = Date(timeIntervalSince1970: 1_800_000_000)
        var message = PushMessage(aps: .init(alert: "test"), user: "Test", commandType: .combo,
                                  carbs: 3, notes: "Remote", sharedSecret: "test",
                                  timestamp: sent.timeIntervalSince1970, overrideName: "Låg")
        let tracker = RemoteCommandReceiptTracker()
        tracker.track(message, id: "without-glucose", site: "test", now: sent)
        precondition(tracker.pending.first?.remaining == [.meal, .override])
        let without = try JSONSerialization.jsonObject(with: JSONEncoder().encode(message)) as! [String: Any]
        precondition(without["glucose"] is NSNull)

        let withTracker = RemoteCommandReceiptTracker()
        message.glucose = Decimal(string: "63.054565") // 3.5 mmol/L in the existing wire format.
        message.scheduledTime = sent.timeIntervalSince1970 - 60
        withTracker.track(message, id: "with-glucose", site: "test", now: sent)
        precondition(withTracker.pending.first?.remaining == [.meal, .override, .glucose])
        let payload = try JSONSerialization.jsonObject(with: JSONEncoder().encode(message)) as! [String: Any]
        precondition(payload["command_type"] as? String == TRCCommandType.combo.rawValue)
        precondition(abs((payload["glucose"] as! NSNumber).doubleValue - 63.054565) < 0.0001)
        func entry(_ id: String, _ type: String, date: Date, extra: [String: Any]) -> [String: Any] {
            var data: [String: Any] = ["_id": id, "eventType": type, "enteredBy": "Trio (Test)",
                                      "created_at": ISO8601DateFormatter().string(from: date)]
            data.merge(extra) { _, value in value }
            return data
        }
        let meal = entry("meal", "Carb Correction", date: sent.addingTimeInterval(-60), extra: ["carbs": 3, "notes": "Remote"])
        let override = entry("override", "Exercise", date: sent, extra: ["notes": "Låg", "duration": 30])
        withTracker.observe([meal, override], site: "test", requestStartedAt: sent.addingTimeInterval(5))
        precondition(withTracker.pending.first?.remaining == [.glucose], "Meal and override must not acknowledge missing glucose")
        let wrong = entry("wrong", "BG Check", date: sent.addingTimeInterval(-60), extra: ["enteredBy": "Trio", "glucose": 100])
        withTracker.observe([wrong], site: "test", requestStartedAt: sent.addingTimeInterval(6))
        precondition(withTracker.pending.first?.remaining == [.glucose])
        let glucose = entry("glucose", "BG Check", date: sent.addingTimeInterval(-60), extra: ["enteredBy": "Trio", "glucose": 3.5, "units": "mmol"])
        withTracker.observe([glucose], site: "test", requestStartedAt: sent.addingTimeInterval(7))
        precondition(withTracker.pending.isEmpty)
        print("Combo glucose tests passed")
    }
}
