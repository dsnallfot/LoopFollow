import Foundation

// swiftc TRCCommandType.swift PushMessage.swift RemoteCommandReceiptTracker.swift <this file> -o /tmp/remote-receipts
@main
struct RemoteReceiptTests {
    static let sent = Date(timeIntervalSince1970: 1_800_000_000)
    static func message(_ type: TRCCommandType = .combo, seconds: Double = 0) -> PushMessage {
        PushMessage(aps: .init(alert: "test"), user: "Skolan", commandType: type,
                    sharedSecret: "secret", timestamp: sent.timeIntervalSince1970 + seconds)
    }
    static func entry(_ id: String, _ type: String, seconds: Double = 1,
                      sender: String = "Trio (Skolan)", extra: [String: Any] = [:]) -> [String: Any] {
        var data: [String: Any] = ["_id": id, "eventType": type, "enteredBy": sender,
                                  "created_at": ISO8601DateFormatter().string(from: sent.addingTimeInterval(seconds))]
        data.merge(extra) { _, value in value }
        return data
    }
    static func main() {
        let tracker = RemoteCommandReceiptTracker()
        func observe(_ entries: [[String: Any]], site: String = "school") {
            tracker.observe(entries, site: site, requestStartedAt: sent.addingTimeInterval(5))
        }
        var combo = message()
        combo.carbs = 3; combo.notes = "🍬"; combo.overrideName = "Låg"
        let meal = entry("meal", "Carb Correction", extra: ["carbs": 3, "notes": "🍬"])
        let override = entry("override", "Exercise", extra: ["notes": "Låg", "duration": 30])
        tracker.track(combo, id: "combo", site: "school", now: sent)
        precondition(tracker.pending.first?.message.sharedSecret == "")
        // Wrong sender/amount, unrelated glucose and error notes cannot clear a combo.
        observe([entry("wrong", "Carb Correction", sender: "Trio (Pappa)", extra: ["carbs": 3, "notes": "🍬"]),
                 entry("wrong2", "Carb Correction", extra: ["carbs": 4, "notes": "🍬"]),
                 entry("error", "Note", extra: ["notes": "🍬"] )])
        precondition(tracker.pending.first?.remaining.count == 2)
        observe([meal], site: "another-site")
        precondition(tracker.pending.first?.remaining.count == 2)
        tracker.observe([meal], site: "school", requestStartedAt: sent.addingTimeInterval(-1))
        precondition(tracker.pending.first?.remaining.count == 2)
        observe([meal])
        precondition(tracker.pending.first?.remaining == [.override])
        var glucose = message(.glucose, seconds: 2)
        glucose.glucose = Decimal(string: "99.099")
        tracker.track(glucose, id: "glucose", site: "school", now: sent.addingTimeInterval(2))
        let fingerstick = entry("bg", "BG Check", seconds: 2, sender: "Trio", extra: ["glucose": "5.5", "units": "mmol"])
        observe([fingerstick])
        precondition(tracker.pending.map(\.id) == ["combo"], "Second receipt must not hide missing first command")
        observe([override])
        precondition(tracker.pending.isEmpty, "Parts can arrive in separate fetches")

        // Existing/backdated treatment is not a fresh receipt.
        var backdated = message(.glucose)
        backdated.glucose = 100; backdated.scheduledTime = sent.timeIntervalSince1970 - 3600
        let old = entry("old", "BG Check", seconds: -3600, sender: "Trio", extra: ["glucose": 100])
        observe([old])
        tracker.track(backdated, id: "backdated", site: "school", now: sent)
        observe([old])
        precondition(tracker.pending.count == 1)
        observe([entry("new", "BG Check", seconds: -3600, sender: "Trio", extra: ["glucose": 100])])
        precondition(tracker.pending.isEmpty)

        // One NS record cannot acknowledge two identical outstanding commands.
        var bolus = message(.bolus); bolus.bolusAmount = 0.5
        tracker.track(bolus, id: "b1", site: "school", now: sent)
        tracker.track(bolus, id: "b2", site: "school", now: sent)
        observe([entry("smb", "Correction Bolus", extra: ["insulin": 0.5, "automatic": true])])
        precondition(tracker.pending.count == 2)
        let bolusEntry = entry("bolus", "Correction Bolus", extra: ["insulin": 0.5])
        observe([bolusEntry]); observe([bolusEntry])
        precondition(tracker.pending.map(\.id) == ["b2"])
        tracker.dismiss(id: "b2", now: sent.addingTimeInterval(29))
        precondition(tracker.pending.count == 1)
        // Thirty seconds makes dismissal possible, never automatic.
        observe([])
        precondition(tracker.pending.count == 1)
        tracker.dismiss(id: "b2", now: sent.addingTimeInterval(30))
        precondition(tracker.pending.isEmpty)

        tracker.track(combo, id: "old-pending", site: "school", now: sent)
        tracker.track(glucose, id: "new-pending", site: "school", now: sent.addingTimeInterval(20))
        tracker.dismiss(id: "old-pending", now: sent.addingTimeInterval(30))
        tracker.dismiss(id: "new-pending", now: sent.addingTimeInterval(30))
        precondition(tracker.pending.map(\.id) == ["new-pending"])
        tracker.rejected(id: "new-pending")
        precondition(tracker.pending.isEmpty)

        var target = message(.tempTarget); target.target = 110; target.duration = 30
        tracker.track(target, id: "target", site: "school", now: sent)
        observe([entry("target", "Temporary Target", seconds: 0, sender: "Trio",
                       extra: ["targetTop": 110, "targetBottom": 110, "duration": 30])])
        precondition(tracker.pending.isEmpty)

        // Cancellation modifies an earlier record; an unchanged or naturally ended run is insufficient.
        let active = entry("active", "Exercise", seconds: -600, extra: ["duration": 60, "notes": "Låg"])
        observe([active])
        tracker.track(message(.cancelOverride), id: "cancel", site: "school", now: sent)
        observe([active])
        precondition(tracker.pending.count == 1)
        observe([entry("ended", "Exercise", seconds: -600, extra: ["duration": 10, "notes": "Låg"])])
        precondition(tracker.pending.isEmpty)
        let gate = RemoteCommandReceiptTracker()
        precondition(gate.beginSend(combo, id: "first", site: "school", now: sent))
        precondition(!gate.beginSend(glucose, id: "blocked", site: "school", now: sent))
        gate.dismiss(id: "first", now: sent.addingTimeInterval(29))
        precondition(gate.hasPendingCommands)
        gate.dismiss(id: "first", now: sent.addingTimeInterval(30))
        precondition(gate.beginSend(glucose, id: "after-dismissal", site: "school", now: sent))
        gate.observe([fingerstick], site: "school", requestStartedAt: sent.addingTimeInterval(5))
        precondition(!gate.hasPendingCommands)
        precondition(gate.beginSend(combo, id: "after-receipt", site: "school", now: sent))
        gate.rejected(id: "after-receipt")
        precondition(!gate.hasPendingCommands)
        precondition(gate.beginSend(combo, id: "warned", site: "school", now: sent))
        gate.dismiss(id: "warned", now: sent)
        precondition(gate.hasPendingCommands, "Normal dismissal still requires 30 seconds")
        gate.dismissForExplicitOverride(ids: ["warned"])
        precondition(gate.beginSend(message(.deleteMeal), id: "deletion", site: "school", now: sent),
                     "Explicit override permits immediate deletion")
        gate.dismissForExplicitOverride(ids: ["warned"])
        precondition(gate.pending.map(\.id) == ["deletion"], "Stale confirmation cannot clear a newer send")
        print("Remote receipt checks passed: combo parts, correlation, sender, values, backdating, multiple sends, rejection, dismissal and cancellation")
    }
}
