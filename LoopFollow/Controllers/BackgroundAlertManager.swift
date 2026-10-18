import ActivityKit
import AlarmKit
import AppIntents
import Combine
import Foundation
import SwiftUI
@preconcurrency import UserNotifications

/// Keep stable slot identifiers and the old six-minute identifier for upgrade cleanup.
/// The first and second slots now have configurable delays.
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
    private let defaults = UserDefaults(suiteName: AppConstants.APP_GROUP_ID)!
    private let idsKey = "alarmKit.background.systemIDs.v1"
    private var systemIDs: Set<UUID> = []
    private let notificationIDsKey = "background.notificationIDs.v2"
    private var notificationIDs: Set<String> = []
    // Until monitoring is recovered, preference/authorization callbacks must leave
    // persisted alarms alone. Merely starting the process is not a heartbeat.
    private var monitoringRecovered = false
    private var preferenceObservations: [ObservationToken] = []
    private var subscriptions = Set<AnyCancellable>()

    private init() {
        systemIDs = Set((defaults.stringArray(forKey: idsKey) ?? []).compactMap(UUID.init(uuidString:)))
        notificationIDs = Set(defaults.stringArray(forKey: notificationIDsKey) ?? [])
        notificationIDs.formUnion(BackgroundAlertIdentifier.allCases.map(\.rawValue))
        observe(AlarmKitSettings.enabled)
        observe(UserDefaultsRepository.quietHourEnd)
        observe(UserDefaultsRepository.quietHourStart)
        observe(BackgroundAlertSettings.enabled)
        observe(BackgroundAlertSettings.alarmKitEnabled)
        observe(BackgroundAlertSettings.periodValue)
        observe(BackgroundAlertSettings.firstDelay)
        observe(BackgroundAlertSettings.secondDelay)
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

    private func observe<T>(_ value: UserDefaultsValue<T>) {
        preferenceObservations.append(value.observeChanges { [weak self] _ in
            DispatchQueue.main.async { self?.replaceAlerts() }
        })
    }

    func startBackgroundAlert() {
        // Foreground BLE heartbeats must not re-arm a watchdog just cancelled on activation.
        guard UIApplication.shared.applicationState != .active else { return }
        monitoringRecovered = true
        isAlertScheduled = true
        scheduleBackgroundAlert(force: true)
    }

    func stopBackgroundAlert() {
        monitoringRecovered = true
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
        guard monitoringRecovered || !BackgroundAlertSettings.enabled.value ||
                Storage.shared.backgroundRefreshType.value == .none else { return }
        revision += 1
        if isAlertScheduled, BackgroundAlertSettings.enabled.value,
           Storage.shared.backgroundRefreshType.value != .none, let anchor = lastScheduleDate {
            desiredAlerts = BackgroundAlert.planned(
                since: anchor, isBluetooth: Storage.shared.backgroundRefreshType.value.isBluetooth,
                expectedHeartbeat: BLEManager.shared.expectedHeartbeatInterval()
            )
        } else {
            desiredAlerts = []
        }
        guard worker == nil else { return }
        worker = Task { await applyLatestAlerts() }
    }

    private func applyLatestAlerts() async {
        var backgroundTask = UIBackgroundTaskIdentifier.invalid
        backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "Background watchdog alarms") {
            if backgroundTask != .invalid {
                UIApplication.shared.endBackgroundTask(backgroundTask)
                backgroundTask = .invalid
            }
            // Keep persisted protection if scheduling is interrupted by suspension.
        }
        defer {
            worker = nil
            if backgroundTask != .invalid { UIApplication.shared.endBackgroundTask(backgroundTask) }
        }
        while true {
            let applyingRevision = revision
            let alerts = desiredAlerts
            let oldSystemIDs = systemIDs
            let oldNotificationIDs = notificationIDs
            var allScheduled = true
            for alert in alerts {
                guard applyingRevision == revision else { break }
                if #available(iOS 26.0, *), BackgroundAlertSettings.usesAlarmKit(at: max(alert.fireDate, Date())),
                   AlarmManager.shared.authorizationState == .authorized {
                    let id = UUID()
                    systemIDs.insert(id)
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
                        guard applyingRevision == revision else { break }
                        LogManager.shared.log(category: .backgroundAlerts, message: "Background AlarmKit scheduled: \(alert.identifier), deadline: \(alert.fireDate)", isDebug: true)
                        continue
                    } catch {
                        await cancelSystemAlarm(id)
                        guard applyingRevision == revision else { break }
                        LogManager.shared.log(category: .backgroundAlerts, message: "Background AlarmKit failed; using notification: \(error)")
                    }
                }
                guard applyingRevision == revision else { break }
                let id = alert.identifier + "." + UUID().uuidString
                notificationIDs.insert(id)
                persistIDs() // Also owns a request if the process dies inside add().
                if !(await scheduleNotification(alert, identifier: id)) {
                    allScheduled = false
                    break
                }
            }
            if applyingRevision == revision && allScheduled {
                // Commit only after every replacement is accepted. Until then the old
                // generation remains armed, including across termination/relaunch.
                for id in oldSystemIDs { await cancelSystemAlarm(id) }
                await removeNotifications(oldNotificationIDs)
                LogManager.shared.log(category: .backgroundAlerts,
                    message: "Background watchdog plan committed: \(alerts.count) slots, revision=\(applyingRevision)", isDebug: true)
            } else if applyingRevision != revision {
                // A newer plan follows immediately. Its commit cleans up every
                // persisted generation, including late/partial completions here.
                LogManager.shared.log(category: .backgroundAlerts,
                    message: "Background watchdog plan superseded; protection retained until replacement", isDebug: true)
            } else {
                // Also keep any accepted slots from this partial attempt. On a
                // first installation there may be no older protection at all.
                LogManager.shared.log(category: .backgroundAlerts,
                    message: "Background watchdog replacement incomplete; existing and accepted protection retained")
            }
            if applyingRevision == revision { return }
        }
    }

    private func scheduleNotification(_ alert: BackgroundAlert, identifier: String) async -> Bool {
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
            try await BackgroundAlertSystemIO.add(UNNotificationRequest(identifier: identifier, content: content, trigger: trigger))
            return true
        } catch {
            LogManager.shared.log(category: .backgroundAlerts, message: "Background notification scheduling failed: \(error)")
            return false
        }
    }

    private func removeNotifications(_ identifiers: Set<String>) async {
        guard !identifiers.isEmpty else { return }
        await BackgroundAlertSystemIO.remove(Array(identifiers))
        notificationIDs.subtract(identifiers)
        persistIDs()
    }

    private func cancelSystemAlarm(_ id: UUID) async {
        if await BackgroundAlertSystemIO.cancelAlarm(id) { systemIDs.remove(id) }
        persistIDs()
    }

    private func persistIDs() {
        let notifications = notificationIDs.sorted()
        if defaults.stringArray(forKey: notificationIDsKey) != notifications {
            defaults.set(notifications, forKey: notificationIDsKey)
        }
        let ids = systemIDs.map(\.uuidString).sorted()
        if defaults.stringArray(forKey: idsKey) != ids { defaults.set(ids, forKey: idsKey) }
    }
}

/// These APIs can synchronously wait on a system daemon, even though their public
/// signatures look inexpensive. Never run them on the main actor or during init.
private enum BackgroundAlertSystemIO {
    private static let queue = DispatchQueue(label: "com.loopfollow.watchdog.system-io", qos: .utility)

    static func add(_ request: UNNotificationRequest) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async {
                UNUserNotificationCenter.current().add(request) { error in
                    if let error { continuation.resume(throwing: error) }
                    else { continuation.resume() }
                }
            }
        }
    }

    static func remove(_ identifiers: [String]) async {
        await withCheckedContinuation { continuation in
            queue.async {
                let center = UNUserNotificationCenter.current()
                center.removePendingNotificationRequests(withIdentifiers: identifiers)
                center.removeDeliveredNotifications(withIdentifiers: identifiers)
                continuation.resume()
            }
        }
    }

    static func cancelAlarm(_ id: UUID) async -> Bool {
        await withCheckedContinuation { continuation in
            queue.async {
                guard #available(iOS 26.0, *) else { continuation.resume(returning: true); return }
                do {
                    try AlarmManager.shared.cancel(id: id)
                    continuation.resume(returning: true)
                } catch {
                    // Keep ownership on failure so a later pass can retry cleanup.
                    let absent = (try? AlarmManager.shared.alarms.contains { $0.id == id }) == false
                    continuation.resume(returning: absent)
                }
            }
        }
    }
}

struct BackgroundAlert {
    let identifier: String
    let fireDate: Date
    let body: String
    let soundName: String

    static func planned(since anchor: Date, isBluetooth: Bool, expectedHeartbeat: TimeInterval?) -> [Self] {
        let slots: [(BackgroundAlertIdentifier, Int, String)] = [
            (.twelveMin, BackgroundAlertSettings.firstMinutes, "Sci-Fi_Computer_Console_Alarm.caf"),
            (.eighteenMin, BackgroundAlertSettings.secondMinutes, "Emergency_Alarm_Carbon_Monoxide.caf")
        ]
        return slots.compactMap { identifier, minutes, sound in
            let interval = TimeInterval(minutes * 60)
            if let heartbeat = expectedHeartbeat, heartbeat * 1.2 >= interval { return nil }
            return Self(identifier: identifier.rawValue, fireDate: anchor.addingTimeInterval(interval),
                        body: "App inaktiv i \(minutes) minuter. " + (isBluetooth
                            ? "Kontrollera bluetooth-anslutningen!" : "Öppna för att aktivera igen."),
                        soundName: sound)
        }
    }
}

/// Opening the app resumes its ordinary heartbeat flow and cancels both watchdogs.
/// Stopping just the first system alarm leaves the second escalation armed.
@available(iOS 26.0, *)
struct OpenLoopFollowBackgroundAlertIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Öppna LoopFollow"
    static var isDiscoverable: Bool = false
    static var openAppWhenRun: Bool = true
    func perform() async throws -> some IntentResult { .result() }
}
