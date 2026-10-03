#!/usr/bin/env python3
"""Execute production AlarmKit policy/coordinator with an in-memory system adapter.
The iOS build validates SDK types separately; these tests exercise delivery races,
ID-specific acknowledgement, snooze units and time boundaries without sounding alarms.
"""
from pathlib import Path
import os
import re
import subprocess
import tempfile

repo = Path(__file__).resolve().parents[1]
settings = (repo / 'LoopFollow/Helpers/GlucoseConversion.swift').read_text() + (repo / 'LoopFollow/Controllers/AlarmKit/AlarmKitSettings.swift').read_text()
manager = (repo / 'LoopFollow/Controllers/AlarmKit/LoopFollowAlarmKit.swift').read_text()
manager = manager[:manager.index('\n@available(iOS 26.0, *)\nstruct LoopFollowAlarmMetadata')]
manager = re.sub(r'^import (ActivityKit|AlarmKit|AppIntents|SwiftUI|UserNotifications)\n', '', manager, flags=re.M)
manager = manager.replace('private init()', 'init()') # Recreate the coordinator to exercise persisted ownership.
manager = manager.replace('UserDefaults(suiteName: AppConstants.APP_GROUP_ID)!', 'MemoryDefaults.shared')
# Keep real preference names/defaults, but replace disk persistence with observable memory.
used = set(re.findall(r'UserDefaultsRepository\.(\w+)', settings + manager))
source = (repo / 'LoopFollow/Storage/UserDefaults.swift').read_text()
properties = []
for name in sorted(used):
    match = re.search(r'^    static let ' + name + r' = .*$', source, re.M)
    assert match, name
    properties.append(match.group())

stubs = r'''
import Foundation
import Combine
struct ObservationToken {}
class UserDefaultsValue<T> {
    var value: T { didSet { callbacks.forEach { $0(value) } } }
    var callbacks: [(T) -> Void] = []
    init(key: String, default value: T) { self.value = value }
    func observeChanges(using callback: @escaping (T) -> Void) -> ObservationToken {
        callbacks.append(callback); return ObservationToken()
    }
}
class MemoryDefaults {
    static let shared = MemoryDefaults()
    var values: [String: Any] = [:]
    func data(forKey key: String) -> Data? { values[key] as? Data }
    func stringArray(forKey key: String) -> [String]? { values[key] as? [String] }
    func set(_ value: Any, forKey key: String) { values[key] = value }
}
struct UIBackgroundTaskIdentifier: Equatable { static let invalid = Self() }
class UIApplication {
    static let shared = UIApplication()
    static let didBecomeActiveNotification = Notification.Name("active")
    static let openSettingsURLString = "settings:"
    func open(_ url: URL) async {}
    func beginBackgroundTask(withName: String) -> UIBackgroundTaskIdentifier { .invalid }
    func endBackgroundTask(_ id: UIBackgroundTaskIdentifier) {}
}
struct Color { static let red = Self(); static let white = Self() }
struct AlarmButton { init(text: String, textColor: Color, systemImageName: String) {} }
struct AlarmPresentation {
    struct Alert {
        static var lastTitle = ""
        init(title: LocalizedStringResource, stopButton: AlarmButton? = nil) {
            Self.lastTitle = String(localized: title)
        }
    }
    init(alert: Alert) {}
}
struct AlarmAttributes<T> { init(presentation: AlarmPresentation, tintColor: Color) {} }
struct LoopFollowAlarmMetadata {}
struct SnoozeLoopFollowAlarmIntent { let id: UUID }
struct AlertConfiguration { enum AlertSound { case named(String), `default` } }
struct SystemAlarm { let id: UUID }
@MainActor class AlarmManager {
    static let shared = AlarmManager()
    enum AuthorizationState { case authorized, denied, notDetermined }
    enum Schedule { case fixed(Date) }
    struct AlarmConfiguration<T> {
        static func alarm(schedule: Schedule, attributes: AlarmAttributes<T>, stopIntent: SnoozeLoopFollowAlarmIntent,
                          sound: AlertConfiguration.AlertSound) -> Self { Self() }
    }
    var authorizationState: AuthorizationState = .authorized
    var authorizationUpdates: AsyncStream<AuthorizationState> { AsyncStream { _ in } }
    func requestAuthorization() async throws -> AuthorizationState { authorizationState }
    var storedAlarms: [SystemAlarm] = []
    var alarms: [SystemAlarm] { get throws { storedAlarms } }
    var schedules = 0
    var fail = false
    var failCancellation = false
    var onSchedule: (() -> Void)?
    var suspension: CheckedContinuation<Void, Never>?
    var suspendNext = false
    func schedule<T>(id: UUID, configuration: AlarmConfiguration<T>) async throws -> SystemAlarm {
        schedules += 1
        onSchedule?()
        if suspendNext { suspendNext = false; await withCheckedContinuation { suspension = $0 } }
        if fail { throw NSError(domain: "test", code: 1) }
        let alarm = SystemAlarm(id: id); storedAlarms.append(alarm); return alarm
    }
    func cancel(id: UUID) throws {
        if failCancellation { throw NSError(domain: "cancel", code: 1) }
        storedAlarms.removeAll { $0.id == id }
    }
    func stop(id: UUID) throws { try cancel(id: id) }
}
final class UNUserNotificationCenter {
    static func current() -> UNUserNotificationCenter { Self() }
    func removePendingNotificationRequests(withIdentifiers: [String]) {}
    func removeDeliveredNotifications(withIdentifiers: [String]) {}
}
class LogManager {
    enum Category { case alarm }
    static let shared = LogManager()
    func log(category: Category, message: String) {}
}
class Storage {
    static let shared = Storage()
    var history: [String] = []
    func appendAlarmHistory(alarmLabel: String, message: String, date: Double) { history.append(alarmLabel) }
}
class FakeAlarmView { func reloadIsSnoozed(key: String, value: Bool) {} }
class ViewControllerManager {
    static let shared = ViewControllerManager()
    let alarmViewController: FakeAlarmView? = nil
}
'''
checks = r'''
@main struct Tests {
    @MainActor static func main() async {
        for minute in 0..<1440 {
            let day = AlarmKitPeriod.day.includes(minute: minute, dayStart: 420, nightStart: 1320)
            precondition(day == (minute >= 420 && minute < 1320))
            precondition(AlarmKitPeriod.night.includes(minute: minute, dayStart: 420, nightStart: 1320) != day)
            let reversed = AlarmKitPeriod.day.includes(minute: minute, dayStart: 1320, nightStart: 420)
            precondition(reversed != day)
            precondition(!AlarmKitPeriod.day.includes(minute: minute, dayStart: 420, nightStart: 420))
            precondition(AlarmKitPeriod.night.includes(minute: minute, dayStart: 420, nightStart: 420))
            precondition(AlarmKitPeriod.always.includes(minute: minute, dayStart: 420, nightStart: 1320))
            precondition(!AlarmKitPeriod.never.includes(minute: minute, dayStart: 420, nightStart: 1320))
        }
        precondition(!AlarmKitSettings.enabled.value)
        let calendar = Calendar.current
        func time(_ hour: Int, _ minute: Int = 0) -> Date {
            calendar.date(bySettingHour: hour, minute: minute, second: 0, of: Date())!
        }
        precondition(AlarmKitSettings.allows(.day, at: time(23)))
        precondition(!AlarmKitSettings.allows(.night, at: time(23)))
        UserDefaultsRepository.quietHourStart.value = time(21, 30)
        UserDefaultsRepository.quietHourEnd.value = time(8, 15)
        precondition(!AlarmKitSettings.allows(.day, at: time(8, 14)))
        precondition(AlarmKitSettings.allows(.day, at: time(8, 15)))
        precondition(AlarmKitSettings.allows(.night, at: time(21, 30)))
        precondition(!AlarmKitSettings.allows(.night, at: time(21, 29)))
        UserDefaultsRepository.quietHourStart.value = time(23)
        precondition(AlarmKitSettings.allows(.day, at: time(22)))
        precondition(AlarmKitSettings.allows(.always, at: time(23)))
        precondition(!AlarmKitSettings.allows(.never, at: time(12)))
        precondition(AlarmKitAlarm.allCases.count == 16)
        for alarm in AlarmKitAlarm.allCases {
            precondition(AlarmKitAlarm.from(label: alarm.label + " AlarmKit") == alarm)
            precondition(!alarm.enabled.value)
        }
        precondition(AlarmKitAlarm.from(label: "⚠️ Snart akut låg! (Comp. low?)") == .urgentLow)
        precondition(AlarmKitAlarm.from(label: "🔴 Lågt socker (Comp. low?) AlarmKit") == .low)
        precondition(AlarmKitAlarm.from(label: "unknown") == nil)
        UserDefaultsRepository.alertLowSnooze.value = 7
        UserDefaultsRepository.alertIOBSnoozeHours.value = 2
        UserDefaultsRepository.alertSAGESnooze.value = 3
        precondition(AlarmKitAlarm.low.defaultSnoozeSeconds == 420)
        precondition(AlarmKitAlarm.iob.defaultSnoozeSeconds == 7200)
        precondition(AlarmKitAlarm.sage.defaultSnoozeSeconds == 10800)
        let now = Date()
        for alarm in AlarmKitAlarm.allCases where alarm != .temporary {
            alarm.acknowledge(at: now)
            precondition(alarm.snoozed?.value == true)
            precondition(alarm.snoozedUntil?.value == now.addingTimeInterval(alarm.defaultSnoozeSeconds))
            alarm.snoozed?.value = false
        }
        AlarmKitAlarm.low.snoozed?.value = true
        AlarmKitAlarm.low.snoozedUntil?.value = now.addingTimeInterval(9999)
        AlarmKitAlarm.low.acknowledge(at: now)
        precondition(AlarmKitAlarm.low.snoozedUntil?.value == now.addingTimeInterval(9999))
        AlarmKitAlarm.low.snoozed?.value = false
        let glucoseKinds: Set<AlarmKitAlarm> = [.urgentLow, .low, .high, .urgentHigh, .fastDrop, .fastRise]
        for kind in AlarmKitAlarm.allCases {
            let title = kind.presentationTitle(label: kind.label, glucoseMGDL: 52)
            precondition(title == kind.label + (glucoseKinds.contains(kind) ? " (2.9 mmol/L)" : ""))
            precondition(kind.presentationTitle(label: kind.label, glucoseMGDL: nil) == kind.label)
            precondition(kind.presentationTitle(label: kind.label, glucoseMGDL: 0) == kind.label)
            precondition(kind.presentationTitle(label: kind.label, glucoseMGDL: -1) == kind.label)
        }
        precondition(AlarmKitAlarm.urgentHigh.presentationTitle(label: "⚠️ Akut högt!", glucoseMGDL: 285) == "⚠️ Akut högt! (15.8 mmol/L)")
        precondition(AlarmKitAlarm.urgentLow.presentationTitle(label: "⚠️ Snart akut låg! (Comp. low?)", glucoseMGDL: 72) == "⚠️ Snart akut låg! (Comp. low?) (4.0 mmol/L)")
        let system = AlarmManager.shared
        let manager = LoopFollowAlarmKit.shared
        let alarm = AlarmKitAlarm.low
        alarm.active.value = true
        var latestGlucose = 52
        func deliver() async -> LoopFollowAlarmKit.Delivery {
            await manager.deliver(label: alarm.label, sound: "Indeed", glucoseMGDL: latestGlucose)
        }
        var result = await deliver()
        precondition(result == .fallback) // Global switch defaults off.
        AlarmKitSettings.enabled.value = true
        result = await deliver(); precondition(result == .fallback) // Individual switch off.
        alarm.enabled.value = true
        alarm.periodValue.value = "never"
        result = await deliver(); precondition(result == .fallback)
        alarm.periodValue.value = "always"
        system.authorizationState = .denied
        result = await deliver(); precondition(result == .fallback)
        system.authorizationState = .authorized
        system.fail = true
        result = await deliver(); precondition(result == .fallback && Storage.shared.history.isEmpty)
        system.fail = false
        result = await deliver(); precondition(result == .delivered)
        precondition(Storage.shared.history == [alarm.label + " AlarmKit"])
        precondition(AlarmPresentation.Alert.lastTitle == alarm.label + " (2.9 mmol/L)")
        let firstID = system.storedAlarms[0].id
        let count = system.schedules
        result = await deliver(); precondition(result == .handled && system.schedules == count)
        manager.acknowledge(id: UUID()) // Stale/unrelated intent does not snooze current event.
        precondition(!alarm.isSnoozed())
        manager.acknowledge(id: firstID)
        precondition(alarm.isSnoozed() && system.storedAlarms.isEmpty)
        let deadline = alarm.snoozedUntil!.value!
        manager.acknowledge(id: firstID)
        precondition(alarm.snoozedUntil!.value == deadline) // Idempotent.
        alarm.snoozedUntil!.value = Date().addingTimeInterval(-1)
        latestGlucose = 65
        result = await deliver(); precondition(result == .delivered)
        precondition(AlarmPresentation.Alert.lastTitle == alarm.label + " (3.6 mmol/L)")
        precondition(Storage.shared.history.last == alarm.label + " AlarmKit")
        // Extending via the existing shared snooze fields cancels the system alarm.
        alarm.snoozedUntil!.value = Date().addingTimeInterval(3600)
        alarm.snoozed!.value = true
        manager.reconcile(); precondition(system.storedAlarms.isEmpty)
        alarm.snoozed!.value = false
        result = await deliver(); precondition(result == .delivered)
        UserDefaultsRepository.alertMuteAllTime.value = Date().addingTimeInterval(3600)
        UserDefaultsRepository.alertMuteAllIsMuted.value = true
        manager.reconcile(); precondition(system.storedAlarms.isEmpty)
        result = await deliver(); precondition(result == .handled)
        UserDefaultsRepository.alertMuteAllTime.value = Date().addingTimeInterval(-1)
        result = await deliver(); precondition(result == .delivered) // Expired flag must not suppress.
        UserDefaultsRepository.alertMuteAllIsMuted.value = false
        UserDefaultsRepository.alertSnoozeAllTime.value = Date().addingTimeInterval(3600)
        UserDefaultsRepository.alertSnoozeAllIsSnoozed.value = true
        manager.reconcile(); precondition(system.storedAlarms.isEmpty)
        result = await deliver(); precondition(result == .handled)
        UserDefaultsRepository.alertSnoozeAllIsSnoozed.value = false
        // A system schedule suspended while a global snooze is set must not resurrect the alarm.
        system.suspendNext = true
        let pending = Task { @MainActor in await deliver() }
        while system.suspension == nil { await Task.yield() }
        UserDefaultsRepository.alertSnoozeAllIsSnoozed.value = true
        manager.reconcile()
        system.suspension?.resume(); system.suspension = nil
        result = await pending.value
        precondition(result == .handled && system.storedAlarms.isEmpty)
        UserDefaultsRepository.alertSnoozeAllIsSnoozed.value = false
        result = await deliver(); precondition(result == .delivered)
        let old = system.storedAlarms[0].id
        system.storedAlarms = [] // System expiry is not a user acknowledgement.
        result = await deliver(); precondition(result == .delivered && !alarm.isSnoozed())
        manager.acknowledge(id: old)
        precondition(!alarm.isSnoozed() && system.storedAlarms.count == 1)
        let liveID = system.storedAlarms[0].id
        let restored = LoopFollowAlarmKit()
        restored.acknowledge(id: liveID)
        precondition(alarm.isSnoozed() && system.storedAlarms.isEmpty)
        alarm.snoozed!.value = false
        manager.reconcile()
        result = await deliver(); precondition(result == .delivered)
        system.failCancellation = true
        AlarmKitSettings.enabled.value = false
        manager.reconcile(); precondition(system.storedAlarms.count == 1)
        precondition(!(MemoryDefaults.shared.stringArray(forKey: "alarmKit.retired.v1") ?? []).isEmpty)
        system.failCancellation = false
        manager.reconcile(); precondition(system.storedAlarms.isEmpty)
        // Temporary alerts are already deactivated by the trigger, but still need delivery and acknowledgement.
        AlarmKitSettings.enabled.value = true
        AlarmKitAlarm.temporary.enabled.value = true
        AlarmKitAlarm.temporary.active.value = false
        result = await manager.deliver(label: AlarmKitAlarm.temporary.label, sound: "Indeed")
        precondition(result == .delivered)
        manager.acknowledge(id: system.storedAlarms[0].id)
        precondition(system.storedAlarms.isEmpty && !AlarmKitAlarm.temporary.active.value)
        print("AlarmKit regressions passed: periods, mappings, snooze units, delivery, failures, cancellation races and exact-ID acknowledgement")
    }
}
'''
with tempfile.TemporaryDirectory(prefix='loopfollow-alarmkit-tests-') as directory:
    directory = Path(directory)
    swift = directory / 'Tests.swift'
    swift.write_text(stubs + '\nclass UserDefaultsRepository {\n' + '\n'.join(properties) + '\n}\n' + settings + manager + checks)
    env = dict(os.environ, CLANG_MODULE_CACHE_PATH=str(directory / 'modules'))
    binary = directory / 'tests'
    subprocess.run(['swiftc', '-parse-as-library', '-swift-version', '5', str(swift), '-o', str(binary)], check=True, env=env)
    subprocess.run([str(binary)], check=True, env=env)
