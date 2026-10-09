import Combine
import EventKit
import Foundation

@MainActor
final class HealthLoggingService: ObservableObject {
    struct ReminderList: Identifiable {
        let id: String
        let title: String
        let account: String
        var displayName: String { "\(title) – \(account)" }
    }

    enum LoggingError: LocalizedError {
        case accessDenied, listUnavailable, fetchFailed, pastReminder
        var errorDescription: String? {
            switch self {
            case .accessDenied: return "Loop Follow behöver full åtkomst till Påminnelser. Du kan ändra behörigheten i telefonens Inställningar."
            case .listUnavailable: return "Välj en skrivbar påminnelselista. Om listan är delad behöver du ha rätt att ändra den."
            case .fetchFailed: return "Påminnelserna kunde inte hämtas. Inga poster har ändrats."
            case .pastReminder: return "Påminnelsetiden har redan passerat. Ändra datumet eller antalet timmar."
            }
        }
    }

    @Published private(set) var lists: [ReminderList] = []
    @Published private(set) var isLoadingLists = false
    private let store = EKEventStore()

    var hasReminderAccess: Bool {
        if #available(iOS 17.0, *) {
            return EKEventStore.authorizationStatus(for: .reminder) == .fullAccess
        }
        return EKEventStore.authorizationStatus(for: .reminder) == .authorized
    }

    func loadLists(requestAccess: Bool) async throws {
        guard !isLoadingLists else { return }
        isLoadingLists = true
        defer { isLoadingLists = false }
        if !hasReminderAccess {
            guard requestAccess else { return }
            let granted: Bool
            if #available(iOS 17.0, *) {
                granted = try await store.requestFullAccessToReminders()
            } else {
                granted = try await withCheckedThrowingContinuation { continuation in
                    store.requestAccess(to: .reminder) { granted, error in
                        if let error { continuation.resume(throwing: error) }
                        else { continuation.resume(returning: granted) }
                    }
                }
            }
            guard granted else { throw LoggingError.accessDenied }
        }
        lists = store.calendars(for: .reminder)
            .filter(\.allowsContentModifications)
            .map { ReminderList(id: $0.calendarIdentifier, title: $0.title, account: $0.source.title) }
            .sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
    }

    func replaceReminder(kind: HealthLogKind, pump: HealthLogPump, eventDate: Date,
                         hours: Int, windowHours: Int, calendarID: String) async throws -> String {
        guard hasReminderAccess else { throw LoggingError.accessDenied }
        guard let calendar = store.calendar(withIdentifier: calendarID), calendar.allowsContentModifications,
              calendar.allowedEntityTypes.contains(.reminder) else { throw LoggingError.listUnavailable }
        let dueDate = HealthLoggingRules.reminderDate(eventDate: eventDate, hours: hours)
        guard dueDate > Date() else { throw LoggingError.pastReminder }
        let predicate = store.predicateForReminders(in: [calendar])
        let existing: [EKReminder] = try await withCheckedThrowingContinuation { continuation in
            store.fetchReminders(matching: predicate) { reminders in
                guard let reminders else {
                    continuation.resume(throwing: LoggingError.fetchFailed)
                    return
                }
                continuation.resume(returning: reminders)
            }
        }
        let replaced = existing.filter {
            HealthLoggingRules.replacesReminder(title: $0.title ?? "", url: $0.url, kind: kind)
        }
        let reminder = EKReminder(eventStore: store)
        reminder.calendar = calendar
        reminder.title = HealthLoggingRules.reminderTitle(kind: kind, pump: pump, windowHours: windowHours)
        reminder.url = kind.reminderURL
        reminder.notes = "Byte registrerat: \(HealthLoggingRules.formattedDate(eventDate))"
        var components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: dueDate)
        components.timeZone = .current
        reminder.dueDateComponents = components
        reminder.addAlarm(EKAlarm(absoluteDate: dueDate))
        do {
            // Stage the replacement before deleting old entries; commit the batch together.
            try store.save(reminder, commit: false)
            for old in replaced { try store.remove(old, commit: false) }
            try store.commit()
        } catch {
            store.reset()
            throw error
        }
        return "Påminnelsen sparades i \(calendar.title). \(replaced.count) tidigare bytespåminnelser ersattes."
    }

    func upload(kind: HealthLogKind, date: Date, title: String, body: String) async throws {
        let payload = HealthLoggingRules.treatment(kind: kind, date: date, title: title, body: body,
                                                   enteredBy: UserDefaultsRepository.caregiverName.value)
        _ = try await NightscoutUtils.executePostRequestRaw(eventType: .treatments, body: payload)
    }
}
