import Foundation

enum HealthLogKind: String, CaseIterable, Identifiable {
    case pump = "Poddbyte"
    case sensor = "Sensorbyte"
    case insulin = "Insulinbyte"
    case note = "Notering"

    var id: String { rawValue }
    var isReminder: Bool { self == .pump || self == .sensor }
    var reminderURL: URL? {
        switch self {
        case .pump: return URL(string: "loopfollow://health-logging/pump")
        case .sensor: return URL(string: "loopfollow://health-logging/sensor")
        default: return nil
        }
    }
}

enum HealthLogPump: String, CaseIterable, Identifiable {
    case omnipod = "Omnipod"
    case medtrum = "Medtrum"
    var id: String { rawValue }
}

enum HealthLoggingRules {
    static let noteTitles = ["Inställningar", "HBA1C", "Ketoner", "Egen rubrik"]

    static func formattedDate(_ date: Date) -> String {
        let locale = Locale(identifier: "sv_SE")
        return date.formatted(Date.FormatStyle(date: .abbreviated, time: .omitted).locale(locale))
            + " kl "
            + date.formatted(Date.FormatStyle(date: .omitted, time: .shortened).locale(locale))
    }

    static func reminderDate(eventDate: Date, hours: Int) -> Date {
        eventDate.addingTimeInterval(Double(hours) * 3600)
    }

    static func reminderTitle(kind: HealthLogKind, pump: HealthLogPump, windowHours: Int) -> String {
        "Byt \(kind == .sensor ? "Sensor" : pump.rawValue) inom \(windowHours)h"
    }

    /// Only this feature's reminders and the shortcut's known title format.
    /// Other reminders in the selected shared list must remain untouched.
    static func replacesReminder(title: String, url: URL?, kind: HealthLogKind) -> Bool {
        guard kind.isReminder else { return false }
        if url == kind.reminderURL { return true }
        let prefixes = kind == .pump ? ["Byt Omnipod inom ", "Byt Medtrum inom "] : ["Byt Sensor inom "]
        return prefixes.contains { title.localizedCaseInsensitiveHasPrefix($0) }
    }

    static func treatment(kind: HealthLogKind, date: Date, title: String, body: String, enteredBy: String) -> [String: Any] {
        precondition(!kind.isReminder)
        let heading = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let detail = body.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = enteredBy.trimmingCharacters(in: .whitespacesAndNewlines)
        let noteTitle = kind == .insulin ? "Ny insulinampull" : heading
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return [
            "eventType": kind == .insulin ? "Insulin Change" : "Note",
            "created_at": formatter.string(from: date),
            "utcOffset": TimeZone.current.secondsFromGMT(for: date) / 60,
            "enteredBy": name.isEmpty ? "LoopFollow" : name,
            "notes": detail.isEmpty ? noteTitle : "\(noteTitle) (\(detail))"
        ]
    }
}

private extension String {
    func localizedCaseInsensitiveHasPrefix(_ prefix: String) -> Bool {
        range(of: prefix, options: [.anchored, .caseInsensitive], locale: Locale(identifier: "sv_SE")) != nil
    }
}
