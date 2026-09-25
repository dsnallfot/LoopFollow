import ActivityKit
import AlarmKit
import AppIntents
import Combine
import Foundation
import SwiftUI
import UserNotifications

/// Only the 12- and 18-minute watchdogs are scheduled. Keep the old notification
/// identifier below so an upgrade also removes outstanding six-minute warnings.
enum BackgroundAlertDuration: TimeInterval, CaseIterable {
    case twelveMinutes = 720
    case eighteenMinutes = 1080
}

enum BackgroundAlertIdentifier: String, CaseIterable {
    case sixMin = "loopfollow.background.alert.6min" // Cleanup only.
    case twelveMin = "loopfollow.background.alert.12min"
    case eighteenMin = "loopfollow.background.alert.18min"
}

/// A heartbeat moves both deadlines. Changes of delivery channel keep those deadlines.
/// A single worker serializes asynchronous scheduling so an obsolete completion cannot
/// cancel or overwrite the notifications belonging to a newer heartbeat.
@MainActor final class BackgroundAlertManager {
    static let shared = BackgroundAlertManager()

    private var isAlertScheduled = false
    private var lastScheduleDate: Date?
    private var revision = 0
    private var desiredAlerts: [BackgroundAlert] = []
    private var worker: Task<Void, Never>?
    private let center = UNUserNotificationCenter.current()
    private let defaults = UserDefaults(suiteName: AppConstants.APP_GROUP_ID)!
    private let idsKey = "alarmKit.background.systemIDs.v1"
    private var systemIDs: Set<UUID> = []
    private var schedulingIDs: Set<UUID> = []
    private var preferenceObservation: ObservationToken?
    private var subscriptions = Set<AnyCancellable>()

    private init() {
        systemIDs = Set((defaults.stringArray(forKey: idsKey) ?? []).compactMap(UUID.init(uuidString:)))
        cancelSystemAlarms()
        removeNotifications()
        preferenceObservation = AlarmKitSettings.enabled.observeChanges { [weak self] _ in
            DispatchQueue.main.async { self?.replaceAlerts() }
        }
        Storage.shared.backgroundRefreshType.$value.dropFirst().receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.replaceAlerts() }.store(in: &subscriptions)
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .receive(on: DispatchQueue.main).sink { [weak self] _ in
                self?.stopBackgroundAlert()
            }.store(in: &subscriptions)
        if #available(iOS 26.0, *) {
            Task { [weak self] in
                for await _ in AlarmManager.shared.authorizationUpdates { self?.replaceAlerts() }
            }
        }
    }

    func startBackgroundAlert() {
        // Foreground BLE heartbeats must not re-arm a watchdog just cancelled on activation.
        guard UIApplication.shared.applicationState != .active else { return }
        isAlertScheduled = true
        scheduleBackgroundAlert(force: true)
    }

    func stopBackgroundAlert() {
        isAlertScheduled = false
        lastScheduleDate = nil
        replaceAlerts()
    }

    func scheduleBackgroundAlert(force: Bool = false) {
        guard isAlertScheduled else { return }
        guard Storage.shared.backgroundRefreshType.value != .none else {
            stopBackgroundAlert()
            return
        }
        let now = Date()
        guard force || now.timeIntervalSince(lastScheduleDate ?? .distantPast) >= 10 else { return }
        lastScheduleDate = now
        replaceAlerts()
    }

    private func replaceAlerts() {
        revision += 1
        if isAlertScheduled, Storage.shared.backgroundRefreshType.value != .none, let anchor = lastScheduleDate {
            desiredAlerts = BackgroundAlert.planned(
                since: anchor, isBluetooth: Storage.shared.backgroundRefreshType.value.isBluetooth,
                expectedHeartbeat: BLEManager.shared.expectedHeartbeatInterval()
            )
        } else {
            desiredAlerts = []
        }
        // Stop existing alarms immediately, even if a preceding schedule is still suspended.
        removeNotifications()
        cancelSystemAlarms()
        guard worker == nil else { return }
        worker = Task { await applyLatestAlerts() }
    }

    private func applyLatestAlerts() async {
        let backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "Background watchdog alarms")
        defer {
            worker = nil
            if backgroundTask != .invalid { UIApplication.shared.endBackgroundTask(backgroundTask) }
        }
        while true {
            let applyingRevision = revision
            let alerts = desiredAlerts
            for alert in alerts {
                guard applyingRevision == revision else { break }
                if #available(iOS 26.0, *), AlarmKitSettings.enabled.value,
                   AlarmManager.shared.authorizationState == .authorized {
                    let id = UUID()
                    systemIDs.insert(id)
                    schedulingIDs.insert(id)
                    persistIDs() // Ownership survives termination during schedule().
                    do {
                        let presentation = AlarmPresentation(alert: AlarmPresentation.Alert(
                            title: LocalizedStringResource(stringLiteral: alert.body),
                            secondaryButton: AlarmButton(text: "Öppna LoopFollow", textColor: .white, systemImageName: "arrow.up.forward.app"),
                            secondaryButtonBehavior: .custom
                        ))
                        let config = AlarmManager.AlarmConfiguration<LoopFollowAlarmMetadata>.alarm(
                            schedule: .fixed(max(alert.fireDate, Date().addingTimeInterval(1))),
                            attributes: AlarmAttributes<LoopFollowAlarmMetadata>(presentation: presentation, tintColor: .orange),
                            secondaryIntent: OpenLoopFollowBackgroundAlertIntent(),
                            sound: .named(alert.soundName)
                        )
                        _ = try await AlarmManager.shared.schedule(id: id, configuration: config)
                        schedulingIDs.remove(id)
                        guard applyingRevision == revision else {
                            cancelSystemAlarm(id)
                            break
                        }
                        LogManager.shared.log(category: .backgroundAlerts, message: "Background AlarmKit scheduled: \(alert.identifier), deadline: \(alert.fireDate)", isDebug: true)
                        continue
                    } catch {
                        schedulingIDs.remove(id)
                        cancelSystemAlarm(id)
                        guard applyingRevision == revision else { break }
                        LogManager.shared.log(category: .backgroundAlerts, message: "Background AlarmKit failed; using notification: \(error)")
                    }
                }
                guard applyingRevision == revision else { break }
                await scheduleNotification(alert)
                if applyingRevision != revision {
                    // No newer notification has been added yet: this worker is serialized.
                    center.removePendingNotificationRequests(withIdentifiers: [alert.identifier])
                    center.removeDeliveredNotifications(withIdentifiers: [alert.identifier])
                    break
                }
            }
            if applyingRevision == revision { return }
        }
    }

    private func scheduleNotification(_ alert: BackgroundAlert) async {
        let content = UNMutableNotificationContent()
        content.title = "LoopFollow Background Refresh"
        content.body = alert.body
        // Preserve the existing notification sound policy. AlarmKit uses the chosen
        // watchdog sound throughout the day, independently of per-glucose periods.
        let hour = Calendar.current.component(.hour, from: alert.fireDate)
        content.sound = hour < 7 || hour >= 21
            ? UNNotificationSound(named: UNNotificationSoundName(alert.soundName)) : .default
        content.interruptionLevel = .timeSensitive
        content.categoryIdentifier = "loopfollow.background.alert"
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, alert.fireDate.timeIntervalSinceNow), repeats: false)
        do {
            try await center.add(UNNotificationRequest(identifier: alert.identifier, content: content, trigger: trigger))
        } catch {
            LogManager.shared.log(category: .backgroundAlerts, message: "Background notification scheduling failed: \(error)")
        }
    }

    private func removeNotifications() {
        let identifiers = BackgroundAlertIdentifier.allCases.map(\.rawValue)
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        center.removeDeliveredNotifications(withIdentifiers: identifiers)
    }

    private func cancelSystemAlarms() {
        for id in systemIDs { cancelSystemAlarm(id) }
    }

    private func cancelSystemAlarm(_ id: UUID) {
        guard #available(iOS 26.0, *) else { return }
        do {
            try AlarmManager.shared.cancel(id: id)
            if !schedulingIDs.contains(id) { systemIDs.remove(id) }
        } catch {
            try? AlarmManager.shared.stop(id: id)
            if !schedulingIDs.contains(id), let alarms = try? AlarmManager.shared.alarms,
               !alarms.contains(where: { $0.id == id }) { systemIDs.remove(id) }
        }
        persistIDs()
    }

    private func persistIDs() {
        let ids = systemIDs.map(\.uuidString).sorted()
        if defaults.stringArray(forKey: idsKey) != ids { defaults.set(ids, forKey: idsKey) }
    }
}

struct BackgroundAlert {
    let identifier: String
    let fireDate: Date
    let body: String
    let soundName: String

    static func planned(since anchor: Date, isBluetooth: Bool, expectedHeartbeat: TimeInterval?) -> [Self] {
        let slots: [(BackgroundAlertIdentifier, BackgroundAlertDuration, String)] = [
            (.twelveMin, .twelveMinutes, "Sci-Fi_Computer_Console_Alarm.caf"),
            (.eighteenMin, .eighteenMinutes, "Emergency_Alarm_Carbon_Monoxide.caf")
        ]
        return slots.compactMap { identifier, duration, sound in
            if let heartbeat = expectedHeartbeat, heartbeat * 1.2 >= duration.rawValue { return nil }
            let minutes = Int(duration.rawValue / 60)
            return Self(identifier: identifier.rawValue, fireDate: anchor.addingTimeInterval(duration.rawValue),
                        body: "App inaktiv i \(minutes) minuter. " + (isBluetooth
                            ? "Kontrollera bluetooth-anslutningen!" : "Öppna för att aktivera igen."),
                        soundName: sound)
        }
    }
}

/// Opening the app resumes its ordinary heartbeat flow and cancels both watchdogs.
/// Stopping just the 12-minute system alarm leaves the 18-minute escalation armed.
@available(iOS 26.0, *)
struct OpenLoopFollowBackgroundAlertIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Öppna LoopFollow"
    static var isDiscoverable: Bool = false
    static var openAppWhenRun: Bool = true
    func perform() async throws -> some IntentResult { .result() }
}
