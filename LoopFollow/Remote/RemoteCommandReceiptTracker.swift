import Foundation
import Combine

/// A local, in-memory reminder, not a delivery acknowledgement or a retry queue.
/// Access on the main thread. Only fresh network responses count as evidence.
final class RemoteCommandReceiptTracker: ObservableObject {
    static let shared = RemoteCommandReceiptTracker()
    static let dismissalDelay: TimeInterval = 30

    enum Part: String, Hashable {
        case meal, bolus, glucose, override, target, cancelOverride, cancelTarget, unknown
    }

    struct Pending: Identifiable {
        let id: String
        let sentAt: Date
        let site: String
        let message: PushMessage
        let baseline: [Treatment]
        let baselineIDs: Set<String>
        var remaining: Set<Part>

        var title: String {
            switch message.commandType {
            case .combo: return "Snabbval"
            case .meal: return "Måltid"
            case .bolus: return "Bolus"
            case .glucose: return "Fingerstick"
            case .startOverride: return "Override"
            case .cancelOverride: return "Avbryt override"
            case .tempTarget: return "Tillfälligt mål"
            case .cancelTempTarget: return "Avbryt tillfälligt mål"
            case .deleteMeal: return "Radera måltid"
            case .deleteGlucose: return "Radera fingerstick"
            }
        }
    }

    struct Treatment {
        private static let fractionalFormatter: ISO8601DateFormatter = {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            return formatter
        }()
        private static let formatter = ISO8601DateFormatter()
        private static let relevantTypes: Set<String> = [
            "Carb Correction", "Meal Bolus", "Kolhydrater", "Dextro", "Måltid",
            "Correction Bolus", "Bolus", "BG Check", "Exercise", "Temporary Override", "Override", "Temporary Target"
        ]
        let raw: [String: Any]
        let date: Date
        let identity: String
        var type: String { raw["eventType"] as? String ?? "" }
        var notes: String { raw["notes"] as? String ?? "" }
        var sender: String { raw["enteredBy"] as? String ?? "" }
        func number(_ key: String) -> Double? {
            if let value = raw[key] as? NSNumber { return value.doubleValue }
            if let value = raw[key] as? String { return Double(value.replacingOccurrences(of: ",", with: ".")) }
            return nil
        }

        init?(_ raw: [String: Any]) {
            guard let type = raw["eventType"] as? String, Self.relevantTypes.contains(type),
                  let text = raw["created_at"] as? String ?? raw["timestamp"] as? String,
                  let date = Self.fractionalFormatter.date(from: text) ?? Self.formatter.date(from: text) else { return nil }
            self.raw = raw
            self.date = date
            // Stable fallback for servers without IDs; deliberately excludes duration,
            // which changes when Trio cancels an existing target/override.
            identity = (raw["_id"] as? String ?? raw["id"] as? String)
                ?? "\(text)|\(raw["eventType"] ?? "")|\(raw["enteredBy"] ?? "")|\(raw["notes"] ?? "")"
        }
    }

    @Published private(set) var pending: [Pending] = []
    private var latest: [String: [Treatment]] = [:]
    private var usedEvidence: Set<String> = []

    var hasPendingCommands: Bool { !pending.isEmpty }

    /// Main-thread check and registration are synchronous so simultaneous sends cannot pass together.
    func beginSend(_ message: PushMessage, id: String, site: String, now: Date = Date()) -> Bool {
        guard !hasPendingCommands else { return false }
        track(message, id: id, site: site, now: now)
        return true
    }

    func track(_ message: PushMessage, id: String, site: String, now: Date = Date()) {
        var parts: Set<Part> = []
        switch message.commandType {
        case .meal, .combo:
            if [message.carbs, message.fat, message.protein].contains(where: { ($0 ?? 0) > 0 }) { parts.insert(.meal) }
            if (message.bolusAmount ?? 0) > 0 { parts.insert(.bolus) }
            if message.commandType == .combo, let name = message.overrideName, !name.isEmpty { parts.insert(.override) }
        case .bolus: parts.insert(.bolus)
        case .glucose: parts.insert(.glucose)
        case .startOverride: parts.insert(.override)
        case .tempTarget: parts.insert(.target)
        case .cancelOverride: parts.insert(.cancelOverride)
        case .cancelTempTarget: parts.insert(.cancelTarget)
        // Absence of a treatment is not enough to prove a deletion succeeded.
        case .deleteMeal, .deleteGlucose: parts.insert(.unknown)
        }
        if parts.isEmpty { parts.insert(.unknown) }
        var metadata = message
        metadata.sharedSecret = ""
        let baseline = latest[site] ?? []
        pending.append(Pending(id: id, sentAt: now, site: site, message: metadata,
                               baseline: baseline, baselineIDs: Set(baseline.map(\.identity)), remaining: parts))
    }

    func rejected(id: String) {
        pending.removeAll { $0.id == id }
    }

    func dismiss(id: String, now: Date = Date()) {
        pending.removeAll { $0.id == id && now.timeIntervalSince($0.sentAt) >= Self.dismissalDelay }
    }

    func observe(_ entries: [[String: Any]], site: String, requestStartedAt: Date) {
        let treatments = entries.compactMap(Treatment.init)
        latest[site] = treatments
        var updated = pending
        for index in updated.indices where updated[index].site == site && requestStartedAt >= updated[index].sentAt {
            let command = updated[index]
            for part in command.remaining {
                if let match = treatments.first(where: {
                    !usedEvidence.contains("\(site)|\($0.identity)|\(part.rawValue)") && matches($0, part: part, command: command)
                }) {
                    usedEvidence.insert("\(site)|\(match.identity)|\(part.rawValue)")
                    updated[index].remaining.remove(part)
                }
            }
        }
        pending = updated.filter { !$0.remaining.isEmpty }
    }

    private func matches(_ entry: Treatment, part: Part, command: Pending) -> Bool {
        let message = command.message
        let sent = message.timestamp
        let timestamp = entry.date.timeIntervalSince1970
        let expectedSender = "Trio (\(message.user))"
        func near(_ actual: Double?, _ expected: Double, tolerance: Double = 0.01) -> Bool {
            guard let actual, actual.isFinite else { return false }
            return abs(actual - expected) <= tolerance
        }
        func executionTime() -> Bool { timestamp >= sent - 5 && timestamp <= sent + 300 }
        func eventTime() -> Bool {
            if let scheduled = message.scheduledTime { return abs(timestamp - scheduled) <= 1 }
            return executionTime()
        }
        let isOverride = ["Exercise", "Temporary Override", "Override"].contains(entry.type)
        if part == .cancelOverride || part == .cancelTarget {
            guard (part == .cancelOverride ? isOverride : entry.type == "Temporary Target"),
                  let duration = entry.number("duration"), duration >= 0 else { return false }
            let end = timestamp + duration * 60
            // Trio rounds completed run durations to whole minutes (minimum one).
            guard end >= sent - 60, end <= sent + 360 else { return false }
            return command.baseline.contains { old in
                old.type == entry.type && old.date == entry.date && old.notes == entry.notes && old.sender == entry.sender &&
                    (old.number("duration") ?? 0) > duration &&
                    timestamp + (old.number("duration") ?? 0) * 60 > sent
            }
        }
        // Existing records, including backdated fingersticks/meals, cannot acknowledge a new send.
        guard !command.baselineIDs.contains(entry.identity) else { return false }
        switch part {
        case .meal:
            return ["Carb Correction", "Meal Bolus", "Kolhydrater", "Dextro", "Måltid"].contains(entry.type) &&
                eventTime() && entry.sender == (message.notes?.isEmpty == false ? expectedSender : "Trio (📲)") &&
                near(entry.number("carbs") ?? 0, Double(message.carbs ?? 0)) &&
                near(entry.number("fat") ?? 0, Double(message.fat ?? 0)) &&
                near(entry.number("protein") ?? 0, Double(message.protein ?? 0)) &&
                entry.notes == (message.notes ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        case .bolus:
            return ["Correction Bolus", "Bolus", "Meal Bolus"].contains(entry.type) &&
                (entry.raw["automatic"] as? Bool) != true && executionTime() && entry.sender == expectedSender &&
                near(entry.number("insulin"), NSDecimalNumber(decimal: message.bolusAmount ?? 0).doubleValue)
        case .glucose:
            guard entry.type == "BG Check", entry.sender == "Trio",
                  abs(timestamp - (message.scheduledTime ?? sent)) <= 1,
                  let glucose = entry.number("glucose") else { return false }
            let mgdl = NSDecimalNumber(decimal: message.glucose ?? 0).doubleValue.rounded(.towardZero)
            let units = (entry.raw["units"] as? String ?? "mg/dl").lowercased()
            if units == "mmol" || units == "mmol/l" {
                return near(glucose, mgdl / 18.018, tolerance: 0.051)
            }
            return units == "mg/dl" && near(glucose, mgdl, tolerance: 0.1)
        case .override:
            return isOverride && executionTime() && entry.sender == expectedSender &&
                entry.notes == message.overrideName && (entry.number("duration") ?? 0) > 0
        case .target:
            return entry.type == "Temporary Target" && abs(timestamp - sent) <= 1 && entry.sender == "Trio" &&
                near(entry.number("targetTop"), Double(message.target ?? 0)) &&
                near(entry.number("targetBottom"), Double(message.target ?? 0)) &&
                near(entry.number("duration"), Double(message.duration ?? 0))
        case .cancelOverride, .cancelTarget, .unknown: return false
        }
    }
}
