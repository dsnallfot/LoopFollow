#!/usr/bin/env python3
"""Exercise real edit sender, draft, encoding and receipts with a transport spy. No APNs sends."""
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
source = (root / 'LoopFollow/Remote/PushNotificationManager.swift').read_text()
sender = source[source.index('    func sendEditMealPushNotification('):source.index('    func sendDeleteMealPushNotification(')]
fixture = r'''
import Foundation
struct Unit { static func gram() -> Unit { Unit() } }
struct Quantity { func doubleValue(for unit: Unit) -> Double { 100 } }
struct Setting { let value = Quantity() }
struct Storage {
    static let shared = Storage()
    let maxCarbs = Setting(), maxProtein = Setting(), maxFat = Setting()
}
class Sender {
    let user = "Skolan", sharedSecret = "fixture-secret"
    var captured: PushMessage?
    var original: [String: Any]?
    var accepted = true
    func sendPushNotification(message: PushMessage, deletingTreatment: [String: Any]?, completion: (Bool, String?) -> Void) {
        captured = message; original = deletingTreatment
        completion(accepted, accepted ? nil : "transport error")
    }
    SENDER
}
@main struct Tests {
    static func main() throws {
        let now = Date()
        let oldDate = Date(timeIntervalSince1970: floor(now.timeIntervalSince1970) - 3600 + 0.789)
        let raw: [String: Any] = ["_id": "original", "carbs": 12, "protein": "3", "fat": 2,
                                  "notes": "Frukt", "foodType": "fallback"]
        let original = MealEditDraft(raw: raw, date: oldDate)
        precondition(original.carbs == "12" && original.protein == "3" && original.fat == "2")
        precondition(original.notes == "Frukt" && original.date.timeIntervalSince1970 == floor(oldDate.timeIntervalSince1970))
        let empty = MealEditDraft(raw: ["foodType": "fallback"], date: oldDate)
        precondition(empty.nutrients == [0, 0, 0] && empty.notes == "fallback")
        precondition(!original.differs(from: original))
        var draft = original
        draft.carbs = " 12,0 "; draft.notes = " Frukt \n"
        precondition(!draft.differs(from: original), "Formatting is not a treatment change")
        for key in [\MealEditDraft.carbs, \.protein, \.fat, \.notes] {
            draft = original; draft[keyPath: key] += "1"
            precondition(draft.differs(from: original))
            draft[keyPath: key] = original[keyPath: key]
            precondition(!draft.differs(from: original))
        }
        draft = original; draft.date += 1
        precondition(draft.differs(from: original))
        func valid(_ value: MealEditDraft) -> Bool {
            value.validationError(originalDate: oldDate, limits: [100, 100, 100], now: now) == nil
        }
        precondition(valid(original))
        for invalid in ["", "-1", "1.5", "nan", "inf", "10000", "101", "abc"] {
            for key in [\MealEditDraft.carbs, \.protein, \.fat] {
                draft = original; draft[keyPath: key] = invalid
                precondition(!valid(draft), "Invalid nutrient accepted: \(invalid)")
            }
        }
        precondition(MealEditDraft.canEdit(now.addingTimeInterval(-MealEditDraft.historyLimit + 1), now: now))
        precondition(!MealEditDraft.canEdit(now.addingTimeInterval(-MealEditDraft.historyLimit), now: now))
        precondition(!MealEditDraft.canEdit(now.addingTimeInterval(1), now: now))
        draft = original; draft.date = now.addingTimeInterval(1); precondition(!valid(draft))
        draft.date = now.addingTimeInterval(-MealEditDraft.historyLimit); precondition(!valid(draft))

        let sender = Sender()
        var callbackCount = 0
        draft = original; draft.carbs = "0"; draft.protein = "0"; draft.fat = "0"; draft.notes = " Ändrad "
        draft.date += 60.456
        precondition(valid(draft))
        sender.sendEditMealPushNotification(draft: draft, originalDate: oldDate, originalTreatment: raw) { success, error in
            precondition(success && error == nil); callbackCount += 1
        }
        let message = sender.captured!
        let json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(message)) as! [String: Any]
        precondition(json["command_type"] as? String == "editMeal")
        precondition(json["original_time"] as? Double == floor(oldDate.timeIntervalSince1970))
        precondition(json["scheduled_time"] as? Double == floor(draft.date.timeIntervalSince1970))
        precondition((json["timestamp"] as! Double) >= now.timeIntervalSince1970)
        precondition(json["carbs"] as? Int == 0 && json["protein"] as? Int == 0 && json["fat"] as? Int == 0)
        precondition(message.bolusAmount == nil && json["bolus_amount"] is NSNull)
        precondition(message.notes == "✎ Ändrad" && sender.original?["_id"] as? String == "original")
        sender.accepted = false
        sender.sendEditMealPushNotification(draft: draft, originalDate: oldDate, originalTreatment: raw) { success, error in
            precondition(!success && error == "transport error"); callbackCount += 1
        }
        sender.captured = nil; draft.carbs = "-1"
        sender.sendEditMealPushNotification(draft: draft, originalDate: oldDate, originalTreatment: raw) { success, error in
            precondition(!success && error != nil); callbackCount += 1
        }
        precondition(sender.captured == nil && callbackCount == 3)

        // A fresh replacement is required, including for zero nutrients, note-only and time-only edits.
        for variant in 0..<3 {
            var edited = message
            if variant == 1 { edited.carbs = 12; edited.protein = 3; edited.fat = 2; edited.scheduledTime = original.date.timeIntervalSince1970 }
            if variant == 2 { edited.carbs = 12; edited.protein = 3; edited.fat = 2; edited.notes = "Frukt" }
            let tracker = RemoteCommandReceiptTracker()
            var replacement: [String: Any] = ["_id": "original", "eventType": "Carb Correction",
                "enteredBy": "Trio (Skolan)", "carbs": edited.carbs!, "protein": edited.protein!, "fat": edited.fat!,
                "notes": edited.notes!.trimmingCharacters(in: .whitespacesAndNewlines),
                "created_at": ISO8601DateFormatter().string(from: Date(timeIntervalSince1970: edited.scheduledTime!))]
            tracker.track(edited, id: "edit", site: "school", now: now, deletingTreatment: replacement)
            func observe(_ rows: [[String: Any]], site: String = "school", started: Date = now) {
                tracker.observe(rows, site: site, requestStartedAt: started)
            }
            observe([replacement])
            precondition(tracker.hasPendingCommands, "Original ID cannot acknowledge edit")
            observe([])
            tracker.observeDeletions([], site: "school", requestStartedAt: now, from: now.addingTimeInterval(-86400), through: now, responseLimit: 5000)
            precondition(tracker.hasPendingCommands, "Disappearance alone cannot acknowledge edit")
            replacement["_id"] = "replacement"
            observe([replacement], site: "other")
            observe([replacement], started: now.addingTimeInterval(-1))
            precondition(tracker.hasPendingCommands)
            for field in ["carbs", "fat", "protein", "notes", "enteredBy", "created_at"] {
                var wrong = replacement
                wrong[field] = ["carbs", "fat", "protein"].contains(field) ? 99 : "incorrect"
                observe([wrong]); precondition(tracker.hasPendingCommands, "Mismatch in \(field) must not acknowledge")
            }
            observe([replacement])
            precondition(!tracker.hasPendingCommands, "Replacement should acknowledge edit variant \(variant)")
        }
        print("Edit meal checks passed: prefill, change detection, limits, age, production sender, wire timestamps, no bolus, callbacks and replacement receipts")
    }
}
'''.replace('    SENDER', sender)
with tempfile.TemporaryDirectory(prefix='edit-meal-tests-') as tmp:
    path = Path(tmp)
    (path / 'fixture.swift').write_text(fixture)
    sources = ['TRC/TRCCommandType.swift', 'PushMessage.swift', 'MealEditDraft.swift', 'RemoteCommandReceiptTracker.swift']
    subprocess.run(['xcrun', 'swiftc', '-module-cache-path', '/tmp/remote-receipt-module-cache',
                    *[str(root / 'LoopFollow/Remote' / name) for name in sources],
                    str(path / 'fixture.swift'), '-o', str(path / 'test')], check=True)
    subprocess.run([str(path / 'test')], check=True)
