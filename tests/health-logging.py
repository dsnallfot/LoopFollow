#!/usr/bin/env python3
"""Exercise production health logging rules and EventKit orchestration with an in-memory store."""
from pathlib import Path
import subprocess
import tempfile
root = Path(__file__).resolve().parents[1]
rules = (root / 'LoopFollow/Remote/TRC/HealthLoggingRules.swift').read_text()
service = (root / 'LoopFollow/Remote/TRC/HealthLoggingService.swift').read_text().replace('import EventKit', '')
fixture = r'''
import Foundation
import Combine
struct Entity: OptionSet { let rawValue: Int; static let reminder = Entity(rawValue: 1) }
enum Auth { case authorized, fullAccess, denied }
final class EKCalendar {
    let calendarIdentifier: String
    let title: String
    var allowsContentModifications = true
    let allowedEntityTypes: Entity = .reminder
    struct Source { let title = "iCloud" }
    let source = Source()
    init(_ id: String, _ title: String) { calendarIdentifier = id; self.title = title }
}
struct EKAlarm { let absoluteDate: Date }
final class EKReminder {
    var calendar: EKCalendar!
    var title: String!
    var url: URL?
    var notes: String?
    var dueDateComponents: DateComponents?
    var alarms: [EKAlarm] = []
    init(eventStore: EKEventStore) {}
    func addAlarm(_ alarm: EKAlarm) { alarms.append(alarm) }
}
final class EKEventStore {
    static var latest: EKEventStore!
    static var access: Auth = .fullAccess
    var calendarsList = [EKCalendar("shared", "Byten"), EKCalendar("other", "Privat")]
    var records: [EKReminder] = []
    var staged: [EKReminder] = []
    var removed: [EKReminder] = []
    var fetchFails = false
    var commitFails = false
    var resets = 0
    var commits = 0
    init() { Self.latest = self }
    static func authorizationStatus(for entity: Entity) -> Auth { access }
    func requestFullAccessToReminders() async throws -> Bool { Self.access == .fullAccess }
    func requestAccess(to entity: Entity, completion: (Bool, Error?) -> Void) { completion(Self.access == .fullAccess, nil) }
    func calendars(for entity: Entity) -> [EKCalendar] { calendarsList }
    func calendar(withIdentifier id: String) -> EKCalendar? { calendarsList.first { $0.calendarIdentifier == id } }
    func predicateForReminders(in calendars: [EKCalendar]) -> String { calendars[0].calendarIdentifier }
    func fetchReminders(matching id: String, completion: ([EKReminder]?) -> Void) {
        completion(fetchFails ? nil : records.filter { $0.calendar.calendarIdentifier == id })
    }
    func save(_ reminder: EKReminder, commit: Bool) throws { precondition(!commit); staged.append(reminder) }
    func remove(_ reminder: EKReminder, commit: Bool) throws { precondition(!commit); removed.append(reminder) }
    func commit() throws {
        if commitFails { throw NSError(domain: "test", code: 1) }
        records.removeAll { old in removed.contains { $0 === old } }
        records.append(contentsOf: staged); staged = []; removed = []; commits += 1
    }
    func reset() { staged = []; removed = []; resets += 1 }
}
enum UserDefaultsRepository { struct Setting { let value = "Förälder" }; static let caregiverName = Setting() }
enum NightscoutUtils {
    enum EventType { case treatments }
    static var bodies: [[String: Any]] = []
    static func executePostRequestRaw(eventType: EventType, body: [String: Any]) async throws -> [String: Any]? {
        bodies.append(body); return nil
    }
}
@main struct Check {
    @MainActor static func main() async throws {
        let service = HealthLoggingService()
        let store = EKEventStore.latest!
        let event = Date().addingTimeInterval(-3600)
        try await service.loadLists(requestAccess: false)
        precondition(service.lists.count == 2)
        func seed(_ title: String, list: String = "shared") -> EKReminder {
            let r = EKReminder(eventStore: store); r.title = title; r.calendar = store.calendar(withIdentifier: list)
            store.records.append(r); return r
        }
        _ = seed("Byt Omnipod inom 8h")
        let sensor = seed("Byt Sensor inom 12h")
        let unrelated = seed("Beställ Omnipod")
        let anotherList = seed("Byt Omnipod inom 8h", list: "other")
        _ = try await service.replaceReminder(kind: .pump, pump: .medtrum, eventDate: event,
                                              hours: 72, windowHours: 8, calendarID: "shared")
        precondition(store.records.count == 4)
        precondition(store.records.contains { $0 === sensor } && store.records.contains { $0 === unrelated })
        precondition(store.records.contains { $0 === anotherList })
        let new = store.records.last!
        precondition(new.title == "Byt Medtrum inom 8h")
        precondition(new.alarms.first!.absoluteDate == event.addingTimeInterval(72 * 3600))
        precondition(new.url == HealthLogKind.pump.reminderURL)
        // Repeating execution replaces, rather than adds another reminder.
        _ = try await service.replaceReminder(kind: .pump, pump: .omnipod, eventDate: event,
                                              hours: 64, windowHours: 8, calendarID: "shared")
        precondition(store.records.count == 4)
        store.fetchFails = true
        do {
            _ = try await service.replaceReminder(kind: .sensor, pump: .omnipod, eventDate: event,
                                                  hours: 240, windowHours: 12, calendarID: "shared")
            preconditionFailure("Fetch failure must abort")
        } catch {}
        precondition(store.commits == 2 && store.records.count == 4)
        store.fetchFails = false; store.commitFails = true
        do {
            _ = try await service.replaceReminder(kind: .sensor, pump: .omnipod, eventDate: event,
                                                  hours: 240, windowHours: 12, calendarID: "shared")
            preconditionFailure("Commit failure must propagate")
        } catch {}
        precondition(store.resets == 1 && store.records.contains { $0 === sensor })
        store.commitFails = false
        store.calendarsList[0].allowsContentModifications = false
        do {
            _ = try await service.replaceReminder(kind: .pump, pump: .omnipod, eventDate: event,
                                                  hours: 64, windowHours: 8, calendarID: "shared")
            preconditionFailure("Read-only list must not be modified")
        } catch {}
        store.calendarsList[0].allowsContentModifications = true
        do {
            _ = try await service.replaceReminder(kind: .pump, pump: .omnipod, eventDate: event.addingTimeInterval(-864000),
                                                  hours: 64, windowHours: 8, calendarID: "shared")
            preconditionFailure("Past reminder must be rejected")
        } catch {}
        precondition(store.commits == 2)
        EKEventStore.access = .denied
        do {
            _ = try await service.replaceReminder(kind: .pump, pump: .omnipod, eventDate: event,
                                                  hours: 64, windowHours: 8, calendarID: "shared")
            preconditionFailure("Permission required")
        } catch {}
        // Nightscout logging is independent of Reminder access.
        try await service.upload(kind: .note, date: event, title: " Ketoner ", body: " 0,1 mmol/L ")
        let payload = NightscoutUtils.bodies.last!
        precondition(payload["eventType"] as? String == "Note")
        precondition(payload["notes"] as? String == "Ketoner (0,1 mmol/L)")
        precondition(payload["enteredBy"] as? String == "Förälder")
        try await service.upload(kind: .insulin, date: event, title: "ignored", body: "")
        precondition(NightscoutUtils.bodies.last!["eventType"] as? String == "Insulin Change")
        precondition(NightscoutUtils.bodies.last!["notes"] as? String == "Ny insulinampull")
        // Elapsed hours remain correct across daylight-saving transitions.
        let start = ISO8601DateFormatter().date(from: "2026-10-24T12:00:00+02:00")!
        precondition(HealthLoggingRules.reminderDate(eventDate: start, hours: 240).timeIntervalSince(start) == 864000)
        print("Health logging passed: scoped replacement, pump switch, repeated save, failures, permissions, payloads, DST")
    }
}
'''
with tempfile.TemporaryDirectory(prefix='health-logging-tests-') as directory:
    tmp = Path(directory)
    path = tmp / 'checks.swift'
    path.write_text(fixture + rules + service)
    subprocess.run(['xcrun', 'swiftc', '-swift-version', '5', '-parse-as-library', '-module-cache-path', str(tmp/'modules'), str(path), '-o', str(tmp/'checks')], check=True)
    subprocess.run([str(tmp/'checks')], check=True)
