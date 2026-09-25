import ActivityKit
import AlarmKit
import AppIntents
import Combine
import SwiftUI
import UserNotifications

/// Owns only AlarmKit deliveries. Thresholds and event detection stay in Alarms.swift.
@available(iOS 26.0, *)
@MainActor final class LoopFollowAlarmKit {
    static let shared = LoopFollowAlarmKit()
    static let changed = Notification.Name("LoopFollow.AlarmKit.changed")

    enum Delivery { case fallback, handled, delivered }
    private struct Event: Codable {
        let id: UUID
        let alarm: AlarmKitAlarm
        let label: String
        let created: Date
    }
    private let defaults = UserDefaults(suiteName: AppConstants.APP_GROUP_ID)!
    private let stateKey = "alarmKit.events.v1"
    private let retiredKey = "alarmKit.retired.v1"
    private var events: [Event] = []
    private var retired: Set<UUID> = []
    private var scheduling: Set<UUID> = []
    private var observations: [ObservationToken] = []
    private var subscriptions = Set<AnyCancellable>()
    private(set) var errorText: String?

    private init() {
        if let data = defaults.data(forKey: stateKey) {
            events = (try? JSONDecoder().decode([Event].self, from: data)) ?? []
        }
        retired = Set((defaults.stringArray(forKey: retiredKey) ?? []).compactMap(UUID.init(uuidString:)))
        observe(AlarmKitSettings.enabled)
        for alarm in AlarmKitAlarm.allCases {
            observe(alarm.enabled)
            observe(alarm.periodValue)
            observe(alarm.active)
            if let value = alarm.snoozed { observe(value) }
            if let value = alarm.snoozedUntil { observe(value) }
        }
        observe(UserDefaultsRepository.alertSnoozeAllTime)
        observe(UserDefaultsRepository.alertSnoozeAllIsSnoozed)
        observe(UserDefaultsRepository.alertMuteAllTime)
        observe(UserDefaultsRepository.alertMuteAllIsMuted)
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .receive(on: DispatchQueue.main).sink { [weak self] _ in
                self?.reconcile()
                self?.notifyUI()
            }.store(in: &subscriptions)
        Task { [weak self] in
            for await _ in AlarmManager.shared.authorizationUpdates {
                self?.reconcile()
                self?.notifyUI()
            }
        }
        // A missing system alarm is not an acknowledgement. Only the stop intent snoozes.
        reconcile()
    }

    private func observe<T>(_ value: UserDefaultsValue<T>) {
        observations.append(value.observeChanges { [weak self] _ in
            // Wait until paired bool/date writes have both completed.
            DispatchQueue.main.async { self?.reconcile() }
        })
    }

    var permissionText: String {
        let status: String
        switch AlarmManager.shared.authorizationState {
        case .authorized: status = "AlarmKit är tillåtet i iOS inställningar."
        case .denied: status = "AlarmKit är inte tillåtet i iOS inställningar. Vanliga larm används."
        case .notDetermined: status = "Tillåt AlarmKit i iOS för att använda systemlarm. Tills dess används vanliga larm."
        @unknown default: status = "AlarmKit är inte tillgängligt. Vanliga larm används."
        }
        return status + (errorText.map { "\n" + $0 } ?? "")
    }

    func requestPermission() async {
        if AlarmManager.shared.authorizationState == .denied {
            if let url = URL(string: UIApplication.openSettingsURLString) { await UIApplication.shared.open(url) }
        } else {
            do {
                _ = try await AlarmManager.shared.requestAuthorization()
                errorText = nil
            } catch {
                errorText = "Kunde inte begära larmbehörighet: \(error.localizedDescription)"
            }
        }
        notifyUI()
    }

    private func notifyUI() { NotificationCenter.default.post(name: Self.changed, object: nil) }

    private func globallySuppressed(at now: Date = Date()) -> Bool {
        let snoozed = UserDefaultsRepository.alertSnoozeAllIsSnoozed.value &&
            (UserDefaultsRepository.alertSnoozeAllTime.value ?? .distantFuture) > now
        let muted = UserDefaultsRepository.alertMuteAllIsMuted.value &&
            (UserDefaultsRepository.alertMuteAllTime.value ?? .distantFuture) > now
        return snoozed || muted
    }

    private func shouldCancel(_ alarm: AlarmKitAlarm) -> Bool {
        !AlarmKitSettings.enabled.value || !alarm.enabled.value || alarm.period == .never ||
            (alarm != .temporary && !alarm.active.value) || alarm.isSnoozed() || globallySuppressed() ||
            AlarmManager.shared.authorizationState != .authorized
    }

    func reconcile() {
        for event in events where shouldCancel(event.alarm) { retire(event.id) }
        for id in retired { cancelSystemAlarm(id) }
    }

    /// Returns handled for a successful delivery, an already ringing alarm, or an explicit suppression.
    func deliver(label: String, sound: String) async -> Delivery {
        reconcile()
        guard let alarm = AlarmKitAlarm.from(label: label) else { return .fallback }
        // An outstanding alarm remains owned by AlarmKit across day/night boundaries.
        if let event = events.first(where: { $0.alarm == alarm }) {
            if scheduling.contains(event.id) { return .handled }
            // Never infer user acknowledgement from expiry or system removal.
            guard let systemAlarms = try? AlarmManager.shared.alarms else { return .handled }
            if systemAlarms.contains(where: { $0.id == event.id }) { return .handled }
            retire(event.id)
        }
        guard alarm.usesAlarmKit(), AlarmManager.shared.authorizationState == .authorized else { return .fallback }
        guard !globallySuppressed(), !alarm.isSnoozed(), alarm == .temporary || alarm.active.value else { return .handled }

        let event = Event(id: UUID(), alarm: alarm, label: label, created: Date())
        events.append(event)
        scheduling.insert(event.id)
        persist() // Persist ownership before suspension, including process termination during schedule.
        let backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "AlarmKit delivery")
        defer {
            scheduling.remove(event.id)
            if retired.contains(event.id) { cancelSystemAlarm(event.id) }
            if backgroundTask != .invalid { UIApplication.shared.endBackgroundTask(backgroundTask) }
        }
        let alert: AlarmPresentation.Alert
        if #available(iOS 26.1, *) {
            // iOS owns the stop control from 26.1; its stopIntent still applies our standard snooze.
            alert = AlarmPresentation.Alert(title: LocalizedStringResource(stringLiteral: label))
        } else {
            alert = AlarmPresentation.Alert(
                title: LocalizedStringResource(stringLiteral: label),
                stopButton: AlarmButton(text: "Snooza", textColor: .white, systemImageName: "zzz")
            )
        }
        let presentation = AlarmPresentation(alert: alert)
        let selectedSound: AlertConfiguration.AlertSound = Bundle.main.url(forResource: sound, withExtension: "caf") != nil
            ? .named(sound + ".caf") : .default
        let config = AlarmManager.AlarmConfiguration<LoopFollowAlarmMetadata>.alarm(
            schedule: .fixed(Date().addingTimeInterval(1)),
            attributes: AlarmAttributes<LoopFollowAlarmMetadata>(presentation: presentation, tintColor: .red),
            stopIntent: SnoozeLoopFollowAlarmIntent(id: event.id), sound: selectedSound
        )
        do {
            _ = try await AlarmManager.shared.schedule(id: event.id, configuration: config)
            guard events.contains(where: { $0.id == event.id }), !shouldCancel(alarm) else {
                retire(event.id)
                return .handled
            }
            errorText = nil
            let historyLabel = label + " AlarmKit"
            LogManager.shared.log(category: .alarm, message: "Alarm triggered: \(historyLabel)")
            Storage.shared.appendAlarmHistory(alarmLabel: historyLabel, message: "Alarm triggered: \(historyLabel)", date: Date().timeIntervalSince1970)
            // Remove a preceding ordinary notification for this same alarm.
            let center = UNUserNotificationCenter.current()
            center.removePendingNotificationRequests(withIdentifiers: ["alarm." + label])
            center.removeDeliveredNotifications(withIdentifiers: ["alarm." + label])
            notifyUI()
            return .delivered
        } catch {
            let wasCurrent = events.contains { $0.id == event.id }
            retire(event.id)
            guard wasCurrent, !globallySuppressed(), !alarm.isSnoozed() else { return .handled }
            errorText = "AlarmKit kunde inte starta larmet. Ordinarie larm används."
            LogManager.shared.log(category: .alarm, message: "AlarmKit scheduling failed: \(error)")
            notifyUI()
            return .fallback
        }
    }

    func acknowledge(id: UUID) {
        guard let event = events.first(where: { $0.id == id }) else { return }
        event.alarm.acknowledge()
        retire(id)
        LogManager.shared.log(category: .alarm, message: "Snoozed alarm: \(event.label) AlarmKit")
        ViewControllerManager.shared.alarmViewController?.reloadIsSnoozed(key: "AlarmKit", value: true)
        notifyUI()
    }

    private func retire(_ id: UUID) {
        events.removeAll { $0.id == id }
        retired.insert(id)
        persist()
        cancelSystemAlarm(id)
    }

    private func cancelSystemAlarm(_ id: UUID) {
        // Keep a tombstone while scheduling so a late successful completion is cancelled too.
        do {
            try AlarmManager.shared.cancel(id: id)
            if !scheduling.contains(id) { retired.remove(id) }
        } catch {
            try? AlarmManager.shared.stop(id: id)
            if !scheduling.contains(id), let alarms = try? AlarmManager.shared.alarms,
               !alarms.contains(where: { $0.id == id }) { retired.remove(id) }
        }
        persist()
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(events), defaults.data(forKey: stateKey) != data {
            defaults.set(data, forKey: stateKey)
        }
        let ids = retired.map(\.uuidString).sorted()
        if defaults.stringArray(forKey: retiredKey) != ids { defaults.set(ids, forKey: retiredKey) }
    }
}

@available(iOS 26.0, *)
struct LoopFollowAlarmMetadata: AlarmMetadata {}

/// Runs in the app process even when the phone is locked or the app must be relaunched.
@available(iOS 26.0, *)
struct SnoozeLoopFollowAlarmIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Snooza LoopFollow-larm"
    static var isDiscoverable: Bool = false
    @Parameter(title: "Larm-ID") var alarmID: String
    init() {}
    init(id: UUID) { alarmID = id.uuidString }
    func perform() async throws -> some IntentResult {
        if let id = UUID(uuidString: alarmID) { await LoopFollowAlarmKit.shared.acknowledge(id: id) }
        return .result()
    }
}
