import Foundation

@main
struct DeletionReceiptTests {
    static func main() {
        let sent = Date(timeIntervalSince1970: 1_800_000_000)
        let oldDate = sent.addingTimeInterval(-3 * 86400)
        let iso = ISO8601DateFormatter()
        func row(_ id: String, type: String = "BG Check", date: Date = oldDate) -> [String: Any] {
            ["_id": id, "eventType": type, "created_at": iso.string(from: date), "glucose": 99, "carbs": 3]
        }
        func message(_ type: TRCCommandType) -> PushMessage {
            PushMessage(aps: .init(alert: ""), user: "Test", commandType: type, sharedSecret: "",
                        timestamp: sent.timeIntervalSince1970, scheduledTime: oldDate.timeIntervalSince1970)
        }
        for (kind, type) in [(TRCCommandType.deleteMeal, "Carb Correction"), (.deleteGlucose, "BG Check")] {
            let tracker = RemoteCommandReceiptTracker()
            let original = row("original", type: type)
            tracker.track(message(kind), id: "delete", site: "home", now: sent, deletingTreatment: original)
            func observe(_ entries: [[String: Any]], site: String = "home", start: Date = sent,
                         from: Date = oldDate.addingTimeInterval(-3600), limit: Int = 5000) {
                tracker.observeDeletions(entries, site: site, requestStartedAt: start,
                                         from: from, through: sent, responseLimit: limit)
            }
            // Ordinary registration observations (or optimistic local removal) cannot clear deletion.
            tracker.observe([], site: "home", requestStartedAt: sent)
            precondition(tracker.hasPendingCommands)
            observe([original])
            precondition(tracker.hasPendingCommands, "Original still exists")
            observe([], site: "different-server")
            observe([], start: sent.addingTimeInterval(-1))
            observe([], from: sent.addingTimeInterval(-86400))
            precondition(tracker.hasPendingCommands, "Wrong site, stale fetch or out-of-window target")
            observe([row("unrelated", date: sent)], limit: 1)
            precondition(tracker.hasPendingCommands, "Capped responses cannot prove absence")
            observe([["_id": "broken", "eventType": type, "created_at": "bad date"]])
            precondition(tracker.hasPendingCommands, "Malformed response cannot prove absence")
            observe([row("replacement", type: type)])
            precondition(tracker.hasPendingCommands, "New ID at same treatment time is still present")
            observe([row("original", type: "Note", date: sent)])
            precondition(tracker.hasPendingCommands, "Same ID with edited type/time is still present")
            observe([row("other", type: type, date: oldDate.addingTimeInterval(60))])
            precondition(!tracker.hasPendingCommands, "Full response covering target proves absence")
        }

        let unseen = RemoteCommandReceiptTracker()
        unseen.track(message(.deleteGlucose), id: "unseen", site: "home", now: sent)
        unseen.observeDeletions([], site: "home", requestStartedAt: sent,
                                from: oldDate, through: sent, responseLimit: 5000)
        precondition(unseen.hasPendingCommands, "Never clear a deletion with no observed target")

        let baseline = RemoteCommandReceiptTracker()
        baseline.observe([row("original")], site: "home", requestStartedAt: sent.addingTimeInterval(-10))
        baseline.track(message(.deleteGlucose), id: "baseline", site: "home", now: sent)
        var registration = message(.meal)
        registration.carbs = 3; registration.notes = "Remote"; registration.scheduledTime = nil
        baseline.track(registration, id: "registration", site: "home", now: sent)
        baseline.observeDeletions([], site: "home", requestStartedAt: sent,
                                  from: oldDate, through: sent, responseLimit: 5000)
        precondition(baseline.pending.map(\.id) == ["registration"], "Absence only clears deletion commands")

        let ambiguous = RemoteCommandReceiptTracker()
        ambiguous.observe([row("one"), row("two")], site: "home", requestStartedAt: sent.addingTimeInterval(-10))
        ambiguous.track(message(.deleteGlucose), id: "ambiguous", site: "home", now: sent)
        ambiguous.observeDeletions([], site: "home", requestStartedAt: sent,
                                   from: oldDate, through: sent, responseLimit: 5000)
        precondition(ambiguous.hasPendingCommands, "Ambiguous baseline must not choose a target arbitrarily")
        print("Deletion receipts passed: meals, fingersticks, exact target, replacement, full window, stale/partial/malformed responses and unchanged registration tracking")
    }
}
