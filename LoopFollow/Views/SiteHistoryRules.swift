import Foundation

enum SiteHistoryFilter: String, CaseIterable, Identifiable {
    case pump = "Pumpar"
    case sensor = "Sensorer"
    case all = "Alla"

    var id: String { rawValue }
}

struct SiteHistoryEntry: Identifiable {
    let id: String
    let date: Date
    let kind: SiteHistoryFilter
    let site: HealthLogSite

    init?(id: String, date: Date, eventType: String, notes: String?) {
        guard eventType == "Note", let notes else { return nil }
        let parts = notes.split(separator: ":", maxSplits: 1).map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard parts.count == 2, let site = HealthLogSite(rawValue: parts[1]) else { return nil }
        switch parts[0] {
        case "Pumpsite": kind = .pump
        case "Sensorsite": kind = .sensor
        default: return nil
        }
        self.id = id
        self.date = date
        self.site = site
    }
}

/// Count the assigned site on each saved session, never its source note as an extra entry.
struct SiteHistorySummary {
    struct Entry {
        let kind: SiteHistoryFilter
        let site: HealthLogSite
    }

    let entries: [Entry]

    init(pumps: [PumpChangeHistoryEntry], sensors: [SensorStartHistoryEntry], filter: SiteHistoryFilter) {
        var seen = Set<String>()
        var result: [Entry] = []
        func append(kind: SiteHistoryFilter, date: TimeInterval, rawSite: String?) {
            guard filter == .all || kind == filter,
                  let rawSite, let site = HealthLogSite(rawValue: rawSite),
                  seen.insert("\(kind.rawValue):\(date)").inserted else { return }
            result.append(Entry(kind: kind, site: site))
        }
        for pump in pumps { append(kind: .pump, date: pump.date, rawSite: pump.site) }
        for sensor in sensors { append(kind: .sensor, date: sensor.date, rawSite: sensor.site) }
        entries = result
    }

    var pumpCount: Int { entries.filter { $0.kind == .pump }.count }
    var sensorCount: Int { entries.filter { $0.kind == .sensor }.count }
    func count(at site: HealthLogSite) -> Int { entries.filter { $0.site == site }.count }
}
