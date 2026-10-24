import Foundation
import CryptoKit

/// Persist totals and their exact boundaries, not only a rounded daily average.
struct SiteSessionMetric: Codable, Equatable {
    static let currentVersion = 1
    var start: TimeInterval
    var end: TimeInterval
    var total: Double
    var sourceDigest: String
    var version = currentVersion
    var usageStart: TimeInterval?

    var dailyAverage: Double? {
        guard end > start, total.isFinite, total >= 0 else { return nil }
        return total * 86400 / (end - start)
    }

    func matches(start: TimeInterval, end: TimeInterval) -> Bool {
        version == Self.currentVersion && self.start == start && self.end == end && dailyAverage != nil
    }
}

struct SiteInsulinData {
    struct Point { let date: TimeInterval; let value: Double }
    var basal: [Point]
    var bolus: [Point]
    var availableDays: Set<Int>
    var updatedAt: Date
}

enum SiteSessionAnalytics {
    static func digest(_ text: String) -> String {
        SHA256.hash(data: Data(text.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    /// Half-open intervals ensure a dose/site note at a change belongs only to the new session.
    static func linkedNotes(_ notes: [SiteHistoryEntry], starts: [TimeInterval], kind: SiteHistoryFilter) -> [TimeInterval: SiteHistoryEntry] {
        let ordered = Array(Set(starts)).sorted()
        var result: [TimeInterval: SiteHistoryEntry] = [:]
        for note in notes.filter({ $0.kind == kind }).sorted(by: {
            $0.date == $1.date ? $0.id < $1.id : $0.date < $1.date
        }) {
            let timestamp = note.date.timeIntervalSince1970
            guard let start = ordered.last(where: { $0 <= timestamp }) else { continue }
            result[start] = note
        }
        return result
    }

    static func insulin(start: TimeInterval, end: TimeInterval, data: SiteInsulinData,
                        previous: SiteSessionMetric?) -> SiteSessionMetric? {
        guard end > start, end <= data.updatedAt.timeIntervalSince1970 + 300,
              let lastBasal = data.basal.last, lastBasal.date >= end - 300 else { return nil }
        let firstDay = Int(floor(start / 86400))
        let lastDay = Int(floor(end.nextDown / 86400))
        guard (firstDay...lastDay).allSatisfy({ data.availableDays.contains($0) }) else { return nil }
        // A rate at or before pump start is required; never silently assume zero basal.
        guard let initial = data.basal.last(where: { $0.date <= start }), initial.value.isFinite, initial.value >= 0 else { return nil }
        let basal = [initial] + data.basal.filter { $0.date > start && $0.date < end }
        let bolus = data.bolus.filter { $0.date >= start && $0.date < end }
        guard basal.allSatisfy({ $0.value.isFinite && $0.value >= 0 }),
              bolus.allSatisfy({ $0.value.isFinite && $0.value >= 0 }) else { return nil }
        let key = digest("basal:" + basal.map { "\($0.date):\($0.value)" }.joined(separator: ",")
                         + "|bolus:" + bolus.map { "\($0.date):\($0.value)" }.joined(separator: ","))
        if let previous, previous.matches(start: start, end: end), previous.sourceDigest == key { return previous }
        let events = basal.map { StatsBasalEngine.BasalChangeEvent(date: Date(timeIntervalSince1970: $0.date), rateUph: $0.value) }
        // Use the statistics engine, clipped to the exact session (including partial first/last days).
        let simulated = StatsBasalEngine.simulateDeliveredBasal(events: events,
            in: DateInterval(start: Date(timeIntervalSince1970: start), end: Date(timeIntervalSince1970: end)))
        return SiteSessionMetric(start: start, end: end,
                                 total: simulated.totalUnits + bolus.reduce(0) { $0 + $1.value }, sourceDigest: key)
    }

    static func mean(_ values: [Double]) -> Double? {
        values.isEmpty ? nil : values.reduce(0, +) / Double(values.count)
    }

    static func dailyAverage(_ metrics: [SiteSessionMetric]) -> Double? {
        let valid = metrics.filter { $0.dailyAverage != nil }
        let duration = valid.reduce(0) { $0 + $1.end - $1.start }
        return duration > 0 ? valid.reduce(0) { $0 + $1.total } * 86400 / duration : nil
    }
}

struct SiteSessionStatistics {
    let pumps: [PumpChangeHistoryEntry]
    let sensors: [SensorStartHistoryEntry]
    let currentPumpMetric: SiteSessionMetric?
    let now: Date

    func pumpDurationHours(site: HealthLogSite?) -> Double? {
        let starts = Array(Set(pumps.map(\.date))).sorted()
        let durations = pumps.compactMap { pump -> Double? in
            guard site == nil || pump.site == site?.rawValue,
                  let end = starts.first(where: { $0 > pump.date }), end <= now.timeIntervalSince1970 else { return nil }
            return (end - pump.date) / 3600
        }
        return SiteSessionAnalytics.mean(durations)
    }

    func sensorDurationDays(site: HealthLogSite?) -> Double? {
        SiteSessionAnalytics.mean(sensors.compactMap { sensor in
            guard site == nil || sensor.site == site?.rawValue,
                  let end = sensors.map(\.usageStartTimestamp).filter({ $0 > sensor.usageStartTimestamp }).min(),
                  end <= now.timeIntervalSince1970, end > sensor.date else { return nil }
            return (end - sensor.date) / 86400
        })
    }

    func pumpMetrics(site: HealthLogSite?) -> [SiteSessionMetric] {
        let starts = Array(Set(pumps.map(\.date))).sorted()
        return pumps.compactMap { pump in
            guard site == nil || pump.site == site?.rawValue else { return nil }
            if let end = starts.first(where: { $0 > pump.date }), end <= now.timeIntervalSince1970 {
                guard let metric = pump.insulinSummary, metric.matches(start: pump.date, end: end) else { return nil }
                return metric
            }
            guard let currentPumpMetric, currentPumpMetric.start == pump.date,
                  currentPumpMetric.end <= now.timeIntervalSince1970,
                  now.timeIntervalSince1970 - currentPumpMetric.end <= 300 else { return nil }
            return currentPumpMetric
        }
    }

    func compressionLowCounts(site: HealthLogSite?) -> [Int] {
        var seen = Set<TimeInterval>()
        return sensors.compactMap { sensor in
            guard site == nil || sensor.site == site?.rawValue,
                  let timestamps = sensor.suspectedCompressionLows,
                  seen.insert(sensor.usageStartTimestamp).inserted else { return nil }
            let window = sensor.sensorUsageWindow(in: sensors, now: now)
            return Set(timestamps.filter { window.contains($0) }).count
        }
    }

    func sensorMetrics(site: HealthLogSite?) -> [SiteSessionMetric] {
        sensors.compactMap { sensor in
            guard site == nil || sensor.site == site?.rawValue,
                  let end = sensors.map(\.usageStartTimestamp).filter({ $0 > sensor.usageStartTimestamp }).min(),
                  end <= now.timeIntervalSince1970,
                  let metric = sensor.siteErrorSummary, metric.matches(start: sensor.date, end: end),
                  metric.usageStart == sensor.usageStartTimestamp else { return nil }
            return metric
        }
    }
}
