#!/usr/bin/env python3
"""Run the production watchdog coordinator against fake iOS scheduling services.
No real notifications or alarms are created. SDK integration is verified by xcodebuild.
"""
from pathlib import Path
import os
import re
import subprocess
import tempfile

repo = Path(__file__).resolve().parents[1]
source = (repo / 'LoopFollow/Controllers/BackgroundAlertManager.swift').read_text()
source = source[:source.index('/// Opening the app resumes')]
source = re.sub(r'^import (ActivityKit|AlarmKit|AppIntents|SwiftUI|UserNotifications)\n', '', source, flags=re.M)
source = source.replace('UserDefaults(suiteName: AppConstants.APP_GROUP_ID)!', 'MemoryDefaults.shared')
source = source.replace('private init()', 'init()')
source = source.replace('private var worker:', 'var worker:')
settings = (repo / 'LoopFollow/Controllers/AlarmKit/AlarmKitSettings.swift').read_text()
settings = settings[:settings.index('/// Stable identifiers;')]
stubs = r'''
import Foundation
import Combine
enum AlarmLaunchNavigation { static func captureRingingAlarm() {} }
struct ObservationToken {}
class UserDefaultsValue<T> {
    var value: T { didSet { callbacks.forEach { $0(value) } } }
    var callbacks: [(T) -> Void] = []
    init(key: String, default value: T) { self.value = value }
    func observeChanges(_ callback: @escaping (T) -> Void) -> ObservationToken {
        callbacks.append(callback); return ObservationToken()
    }
}
enum UserDefaultsRepository {
    static let quietHourStart = UserDefaultsValue<Date?>(key: "quietHourStart", default: nil)
    static let quietHourEnd = UserDefaultsValue<Date?>(key: "quietHourEnd", default: nil)
}
class MemoryDefaults {
    static let shared = MemoryDefaults()
    var values: [String: [String]] = [:]
    func stringArray(forKey key: String) -> [String]? { values[key] }
    func set(_ value: [String], forKey key: String) { values[key] = value }
}
enum RefreshType { case none, bluetooth, silentTune
    var isBluetooth: Bool { self == .bluetooth }
}
class RefreshValue { @Published var value: RefreshType = .bluetooth }
class Storage { static let shared = Storage(); let backgroundRefreshType = RefreshValue() }
class BLEManager {
    static let shared = BLEManager()
    var interval: TimeInterval? = 300
    func expectedHeartbeatInterval() -> TimeInterval? { interval }
}
struct UIBackgroundTaskIdentifier: Equatable { static let invalid = Self() }
class UIApplication {
    static let shared = UIApplication()
    static let didBecomeActiveNotification = Notification.Name("active")
    enum State { case active, inactive, background }
    var applicationState = State.background
    func beginBackgroundTask(withName: String) -> UIBackgroundTaskIdentifier { .invalid }
    func endBackgroundTask(_ id: UIBackgroundTaskIdentifier) {}
}
struct Color { static let orange = Self(); static let white = Self() }
struct AlarmButton { init(text: String, textColor: Color, systemImageName: String) {} }
struct AlarmPresentation {
    struct Alert {
        enum Behavior { case custom }
        init(title: LocalizedStringResource, secondaryButton: AlarmButton, secondaryButtonBehavior: Behavior) {}
    }
    init(alert: Alert) {}
}
struct AlarmAttributes<T> { init(presentation: AlarmPresentation, tintColor: Color) {} }
struct LoopFollowAlarmMetadata {}
struct OpenLoopFollowBackgroundAlertIntent {}
struct AlertConfiguration { enum AlertSound: Equatable { case named(String) } }
struct SystemAlarm { let id: UUID; let date: Date; let sound: AlertConfiguration.AlertSound }
@MainActor class AlarmManager {
    static let shared = AlarmManager()
    enum AuthorizationState { case authorized, denied, notDetermined }
    enum Schedule { case fixed(Date) }
    struct AlarmConfiguration<T> {
        let date: Date
        let sound: AlertConfiguration.AlertSound
        static func alarm(schedule: Schedule, attributes: AlarmAttributes<T>, secondaryIntent: OpenLoopFollowBackgroundAlertIntent,
                          sound: AlertConfiguration.AlertSound) -> Self {
            switch schedule { case .fixed(let date): return Self(date: date, sound: sound) }
        }
    }
    var authorizationState: AuthorizationState = .authorized
    var authorizationUpdates: AsyncStream<AuthorizationState> { AsyncStream { _ in } }
    var stored: [SystemAlarm] = []
    var alarms: [SystemAlarm] { get throws { stored } }
    var fail = false
    var schedules = 0
    var suspendNext = false
    var suspension: CheckedContinuation<Void, Never>?
    func schedule<T>(id: UUID, configuration: AlarmConfiguration<T>) async throws -> SystemAlarm {
        schedules += 1
        if suspendNext { suspendNext = false; await withCheckedContinuation { suspension = $0 } }
        if fail { throw NSError(domain: "test", code: 1) }
        let alarm = SystemAlarm(id: id, date: configuration.date, sound: configuration.sound)
        stored.append(alarm); return alarm
    }
    func cancel(id: UUID) throws { stored.removeAll { $0.id == id } }
    func stop(id: UUID) throws { try cancel(id: id) }
}
struct UNNotificationSoundName { let name: String; init(_ name: String) { self.name = name } }
class UNNotificationSound {
    static let `default` = UNNotificationSound()
    init() {}
    init(named: UNNotificationSoundName) {}
}
class UNMutableNotificationContent {
    var title = "", body = "", categoryIdentifier = ""
    var sound: UNNotificationSound?
    enum Level { case timeSensitive }
    var interruptionLevel = Level.timeSensitive
}
struct UNTimeIntervalNotificationTrigger { let timeInterval: TimeInterval; let repeats: Bool }
struct UNNotificationRequest {
    let identifier: String
    let content: UNMutableNotificationContent
    let trigger: UNTimeIntervalNotificationTrigger
}
@MainActor final class UNUserNotificationCenter {
    static let shared = UNUserNotificationCenter()
    static func current() -> UNUserNotificationCenter { shared }
    var requests: [UNNotificationRequest] = []
    var removed: Set<String> = []
    var suspendNext = false
    var suspension: CheckedContinuation<Void, Never>?
    func add(_ request: UNNotificationRequest) async throws {
        if suspendNext { suspendNext = false; await withCheckedContinuation { suspension = $0 } }
        requests.removeAll { $0.identifier == request.identifier }; requests.append(request)
    }
    func removePendingNotificationRequests(withIdentifiers ids: [String]) {
        removed.formUnion(ids); requests.removeAll { ids.contains($0.identifier) }
    }
    func removeDeliveredNotifications(withIdentifiers ids: [String]) { removed.formUnion(ids) }
}
class LogManager {
    enum Category { case backgroundAlerts }
    static let shared = LogManager()
    func log(category: Category, message: String, isDebug: Bool = false) {}
}
'''
checks = r'''
@main struct Tests {
    @MainActor static func settle(_ manager: BackgroundAlertManager) async {
        // Drain main-queue preference observations, then await the actual serialized worker.
        for _ in 0..<5 {
            try? await Task.sleep(nanoseconds: 1_000_000)
            if let worker = manager.worker { await worker.value }
        }
    }
    @MainActor static func main() async {
        precondition(BackgroundAlertSettings.enabled.value && BackgroundAlertSettings.alarmKitEnabled.value)
        precondition(BackgroundAlertSettings.period == .always)
        BackgroundAlertSettings.setFirstMinutes(35)
        precondition(BackgroundAlertSettings.firstMinutes == 30 && BackgroundAlertSettings.secondMinutes == 30)
        BackgroundAlertSettings.setSecondMinutes(70)
        precondition(BackgroundAlertSettings.secondMinutes == 60)
        BackgroundAlertSettings.setFirstMinutes(1)
        precondition(BackgroundAlertSettings.firstMinutes == 10 && BackgroundAlertSettings.secondMinutes == 60)
        BackgroundAlertSettings.setSecondMinutes(1)
        precondition(BackgroundAlertSettings.secondMinutes == 10)
        BackgroundAlertSettings.firstDelay.value = 100 // Invalid imported data cannot bypass the bounds.
        BackgroundAlertSettings.secondDelay.value = -5
        precondition(BackgroundAlertSettings.firstMinutes == 30 && BackgroundAlertSettings.secondMinutes == 30)
        BackgroundAlertSettings.setFirstMinutes(12)
        BackgroundAlertSettings.setSecondMinutes(18)
        let anchor = Date(timeIntervalSince1970: 1234567890)
        let planned = BackgroundAlert.planned(since: anchor, isBluetooth: true, expectedHeartbeat: 300)
        precondition(planned.count == 2)
        precondition(planned.map { $0.fireDate.timeIntervalSince(anchor) } == [720, 1080])
        precondition(planned[0].soundName == "Sci-Fi_Computer_Console_Alarm.caf")
        precondition(planned[1].soundName == "Emergency_Alarm_Carbon_Monoxide.caf")
        precondition(planned.allSatisfy { $0.body.contains("bluetooth") })
        precondition(!BackgroundAlert.planned(since: anchor, isBluetooth: false, expectedHeartbeat: nil)[0].body.contains("bluetooth"))
        precondition(BackgroundAlert.planned(since: anchor, isBluetooth: true, expectedHeartbeat: 600).count == 1)
        precondition(BackgroundAlert.planned(since: anchor, isBluetooth: true, expectedHeartbeat: 900).isEmpty)
        let system = AlarmManager.shared
        let notifications = UNUserNotificationCenter.shared
        let manager = BackgroundAlertManager.shared
        manager.startBackgroundAlert()
        await settle(manager)
        precondition(system.stored.isEmpty && notifications.requests.count == 2)
        precondition(notifications.removed.contains(BackgroundAlertIdentifier.sixMin.rawValue))
        precondition(!notifications.requests.contains { $0.identifier == BackgroundAlertIdentifier.sixMin.rawValue })
        AlarmKitSettings.enabled.value = true
        await settle(manager)
        precondition(system.stored.count == 2 && notifications.requests.isEmpty)
        let dates = system.stored.map(\.date).sorted()
        precondition(abs(dates[1].timeIntervalSince(dates[0]) - 360) < 0.001)
        AlarmKitSettings.enabled.value = false
        await settle(manager)
        precondition(system.stored.isEmpty && notifications.requests.count == 2)
        AlarmKitSettings.enabled.value = true
        await settle(manager)
        precondition(system.stored.map(\.date).sorted() == dates) // Channel changes don't restart the clock.
        // Per-watchdog switch and period select ordinary notifications outside the AlarmKit window.
        BackgroundAlertSettings.alarmKitEnabled.value = false
        await settle(manager)
        precondition(system.stored.isEmpty && notifications.requests.count == 2)
        BackgroundAlertSettings.alarmKitEnabled.value = true
        BackgroundAlertSettings.periodValue.value = AlarmKitPeriod.never.rawValue
        await settle(manager)
        precondition(system.stored.isEmpty && notifications.requests.count == 2)
        // Put the day boundary between the two actual fire dates, including midnight wraparound.
        UserDefaultsRepository.quietHourEnd.value = dates[0].addingTimeInterval(60)
        UserDefaultsRepository.quietHourStart.value = dates[0].addingTimeInterval(60 + 720 * 60)
        BackgroundAlertSettings.periodValue.value = AlarmKitPeriod.day.rawValue
        await settle(manager)
        precondition(system.stored.count == 1 && system.stored[0].date == dates[1])
        precondition(notifications.requests.count == 1 && notifications.requests[0].identifier == BackgroundAlertIdentifier.twelveMin.rawValue)
        BackgroundAlertSettings.periodValue.value = AlarmKitPeriod.night.rawValue
        await settle(manager)
        precondition(system.stored.count == 1 && system.stored[0].date == dates[0])
        precondition(notifications.requests.count == 1 && notifications.requests[0].identifier == BackgroundAlertIdentifier.eighteenMin.rawValue)
        BackgroundAlertSettings.enabled.value = false
        await settle(manager)
        precondition(system.stored.isEmpty && notifications.requests.isEmpty)
        BackgroundAlertSettings.enabled.value = true
        BackgroundAlertSettings.periodValue.value = AlarmKitPeriod.always.rawValue
        BackgroundAlertSettings.setFirstMinutes(19)
        BackgroundAlertSettings.setSecondMinutes(44)
        await settle(manager)
        let customDates = system.stored.map(\.date).sorted()
        precondition(customDates.count == 2)
        precondition(customDates[0] == dates[0].addingTimeInterval(7 * 60))
        precondition(customDates[1] == dates[0].addingTimeInterval(32 * 60))
        precondition(BackgroundAlert.planned(since: anchor, isBluetooth: false, expectedHeartbeat: nil)[1].body.contains("44 minuter"))
        BackgroundAlertSettings.setFirstMinutes(12)
        BackgroundAlertSettings.setSecondMinutes(18)
        await settle(manager)

        let previousCount = system.schedules
        manager.scheduleBackgroundAlert()
        await settle(manager)
        precondition(system.schedules == previousCount) // Ten-second throttle.
        manager.startBackgroundAlert()
        await settle(manager)
        precondition(system.stored.count == 2 && system.stored.map(\.date).min()! > dates[0])
        manager.stopBackgroundAlert()
        await settle(manager)
        precondition(system.stored.isEmpty && notifications.requests.isEmpty)
        system.authorizationState = .denied
        manager.startBackgroundAlert()
        await settle(manager)
        precondition(system.stored.isEmpty && notifications.requests.count == 2)
        system.authorizationState = .authorized
        system.fail = true
        manager.startBackgroundAlert()
        await settle(manager)
        precondition(system.stored.isEmpty && notifications.requests.count == 2)
        system.fail = false
        // App wakes while AlarmKit.schedule is suspended. Its late success must be cancelled.
        system.suspendNext = true
        manager.startBackgroundAlert()
        while system.suspension == nil { await Task.yield() }
        precondition(!(MemoryDefaults.shared.stringArray(forKey: "alarmKit.background.systemIDs.v1") ?? []).isEmpty)
        manager.stopBackgroundAlert()
        system.suspension?.resume(); system.suspension = nil
        await settle(manager)
        precondition(system.stored.isEmpty && notifications.requests.isEmpty)
        // A newer heartbeat supersedes an in-flight schedule without leaving duplicate alarms.
        system.suspendNext = true
        manager.startBackgroundAlert()
        while system.suspension == nil { await Task.yield() }
        manager.startBackgroundAlert()
        system.suspension?.resume(); system.suspension = nil
        await settle(manager)
        precondition(system.stored.count == 2 && notifications.requests.isEmpty)
        // Late notification completion must not overwrite the new AlarmKit plan.
        AlarmKitSettings.enabled.value = false
        notifications.suspendNext = true
        manager.startBackgroundAlert()
        while notifications.suspension == nil { await Task.yield() }
        AlarmKitSettings.enabled.value = true
        manager.startBackgroundAlert()
        notifications.suspension?.resume(); notifications.suspension = nil
        await settle(manager)
        precondition(system.stored.count == 2 && notifications.requests.isEmpty)
        // Relaunch cleanup uses persisted ownership, including when background refresh is off.
        let restored = BackgroundAlertManager()
        precondition(system.stored.isEmpty)
        manager.stopBackgroundAlert()
        await settle(manager)
        UIApplication.shared.applicationState = .active
        restored.startBackgroundAlert()
        await settle(restored)
        precondition(system.stored.isEmpty)
        UIApplication.shared.applicationState = .background
        manager.startBackgroundAlert()
        await settle(manager)
        precondition(system.stored.count == 2)
        Storage.shared.backgroundRefreshType.value = .none
        await settle(manager)
        precondition(system.stored.isEmpty && notifications.requests.isEmpty)
        print("Background AlarmKit regressions passed: configurable delays, bounds, day/night boundaries, enable switches, fallback, cancellation races and relaunch cleanup")
    }
}
'''
with tempfile.TemporaryDirectory(prefix='background-alarmkit-tests-') as directory:
    directory = Path(directory)
    script = directory / 'Tests.swift'
    script.write_text(stubs + settings + source + checks)
    binary = directory / 'tests'
    env = dict(os.environ, CLANG_MODULE_CACHE_PATH=str(directory / 'modules'))
    subprocess.run(['swiftc', '-parse-as-library', '-swift-version', '5', str(script), '-o', str(binary)], check=True, env=env)
    subprocess.run([str(binary)], check=True, env=env, timeout=30)
