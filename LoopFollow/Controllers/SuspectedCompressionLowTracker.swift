import Foundation

/// Local observations of the existing alarm heuristic, not confirmed clinical events.
struct SuspectedCompressionLowHistory: Codable, Equatable {
    struct Event: Codable, Equatable {
        var timestamp: TimeInterval
        var lastDetectedAt: TimeInterval
    }
    var events: [Event] = []
    var lastReading: TimeInterval?
    var episodeActive = false
    var startedAt: TimeInterval?

    struct Observation: Codable, Equatable {
        var timestamp: TimeInterval
        var suspected: Bool
        var recovered: Bool
        var live: Bool
    }
    // Optional for backwards compatibility with previously saved episode-only histories.
    var observations: [Observation]?

    var hitTimestamps: [TimeInterval] {
        observations?.filter(\.suspected).map(\.timestamp) ?? events.flatMap { [$0.timestamp, $0.lastDetectedAt] }
    }

    /// Shared glucose criterion. Live alarms additionally require low current IOB.
    static func matches(current: Double, deltas: [Double], lowThreshold: Double) -> Bool {
        guard current > 0, current <= lowThreshold, deltas.count >= 3 else { return false }
        let previous = max(abs(deltas[1]), abs(deltas[2]))
        return deltas[0] < 0 && previous > 0 && abs(deltas[0]) >= previous * 2
    }

    /// Historical glucose evidence only; never substitutes today's IOB for historical IOB.
    static func calculateSuspectedCompressionLows(_ readings: [SGVJSON], from: TimeInterval,
                                                  to: TimeInterval, lowThreshold: Double) -> [Observation] {
        // Match the combined glucose log's four-minute buckets, preserving the newest value.
        var buckets: [Int: SGVJSON] = [:]
        for reading in readings {
            let time = reading.readingDate.timeIntervalSince1970
            guard time.isFinite, time <= to else { continue }
            let key = Int(floor(time / 240))
            if buckets[key].map({ $0.readingDate < reading.readingDate }) ?? true { buckets[key] = reading }
        }
        let sorted = buckets.values.sorted { $0.readingDate < $1.readingDate }
        var result: [Observation] = []
        for index in sorted.indices where index >= 3 {
            let window = Array(sorted[(index - 3)...index])
            let time = window[3].readingDate.timeIntervalSince1970
            guard time >= from, window.allSatisfy({ $0.sgv > 0 }),
                  (1...3).allSatisfy({ window[$0].readingDate.timeIntervalSince(window[$0 - 1].readingDate) <= 10 * 60 }) else { continue }
            let deltas = (1...3).reversed().map { Double(window[$0].sgv - window[$0 - 1].sgv) }
            result.append(Observation(timestamp: time,
                suspected: matches(current: Double(window[3].sgv), deltas: deltas, lowThreshold: lowThreshold),
                recovered: Double(window[3].sgv) > lowThreshold, live: false))
        }
        return result
    }

    private mutating func migrateObservations() {
        guard observations == nil else { return }
        observations = events.flatMap { event in
            Set([event.timestamp, event.lastDetectedAt]).sorted().map {
                Observation(timestamp: $0, suspected: true, recovered: false, live: true)
            }
        }
        // Legacy storage already distinguished these episodes, even though it did not keep
        // recovery samples. Preserve those boundaries during migration and later replay.
        for pair in zip(events, events.dropFirst()) where pair.0.lastDetectedAt < pair.1.timestamp {
            observations?.append(Observation(timestamp: pair.0.lastDetectedAt.nextUp,
                suspected: false, recovered: true, live: true))
        }
        observations?.sort { $0.timestamp < $1.timestamp }
        if let lastReading, !episodeActive, !(observations ?? []).contains(where: { $0.timestamp == lastReading }) {
            observations?.append(Observation(timestamp: lastReading, suspected: false, recovered: true, live: true))
        }
    }

    /// Live results win over historical glucose-only estimates, including live negative results.
    mutating func mergeHistorical(_ incoming: [Observation], sensors: inout [SensorStartHistoryEntry]) {
        guard !incoming.isEmpty else { return }
        migrateObservations()
        var byTime: [TimeInterval: Observation] = [:]
        for item in observations ?? [] { byTime[item.timestamp] = item }
        for item in incoming where byTime[item.timestamp]?.live != true { byTime[item.timestamp] = item }
        observations = byTime.values.sorted { $0.timestamp < $1.timestamp }
        events = []
        episodeActive = false
        for item in observations ?? [] { appendEpisode(item, sensors: sensors) }
        // Do not advance the live cursor: an in-flight alarm must still be able to replace a backfilled reading.
        sensors = reconciled(sensors)
    }

    private mutating func appendEpisode(_ item: Observation, sensors: [SensorStartHistoryEntry]) {
        if item.suspected {
            let crossesSensorChange = events.last.map { event in
                sensors.contains { $0.usageStartTimestamp > event.timestamp && $0.usageStartTimestamp <= item.timestamp }
            } ?? false
            if episodeActive, let previous = events.last,
               item.timestamp - previous.lastDetectedAt <= 30 * 60, !crossesSensorChange {
                events[events.count - 1].lastDetectedAt = item.timestamp
            } else {
                events.append(Event(timestamp: item.timestamp, lastDetectedAt: item.timestamp))
            }
            episodeActive = true
        } else if item.recovered { episodeActive = false }
    }

    /// Returns false for stale, future or already evaluated live readings.
    mutating func observe(timestamp: TimeInterval, suspected: Bool, recovered: Bool, now: TimeInterval,
                          sensors: inout [SensorStartHistoryEntry]) -> Bool {
        guard timestamp.isFinite, timestamp <= now, now - timestamp <= 300,
              lastReading.map({ timestamp > $0 }) ?? true else { return false }
        migrateObservations()
        lastReading = timestamp
        if startedAt == nil { startedAt = timestamp }
        let item = Observation(timestamp: timestamp, suspected: suspected, recovered: recovered, live: true)
        if timestamp <= (observations?.last?.timestamp ?? -.infinity) {
            // A just-finished backfill may already contain this sample, or a newer cached sample.
            observations?.removeAll { $0.timestamp == timestamp }
            observations?.append(item)
            mergeHistorical([item], sensors: &sensors)
        } else {
            observations?.append(item)
            appendEpisode(item, sensors: sensors)
            sensors = reconciled(sensors)
        }
        return true
    }

    static func owner(of timestamp: TimeInterval, sensors: [SensorStartHistoryEntry]) -> Int? {
        sensors.indices.filter { sensors[$0].usageStartTimestamp <= timestamp }
            .max { sensors[$0].usageStartTimestamp < sensors[$1].usageStartTimestamp }
    }

    /// Reassign by usage start when late sensor metadata or edited boundaries arrive.
    /// Merge imported timestamps as a set so repeated imports cannot inflate counts.
    func reconciled(_ original: [SensorStartHistoryEntry]) -> [SensorStartHistoryEntry] {
        var result = original
        // Stored session timestamps produced by this ledger must not survive regrouping as extra episodes.
        let evaluated = Set((observations ?? []).map(\.timestamp))
        let imported = original.flatMap { $0.suspectedCompressionLows ?? [] }.filter { !evaluated.contains($0) }
        let timestamps = Set(events.map(\.timestamp) + imported)
        var observations = Set(original.compactMap(\.compressionLowObservedAt))
        if let lastReading { observations.insert(lastReading) }
        observations.formUnion((self.observations ?? []).map(\.timestamp))
        for i in result.indices {
            result[i].suspectedCompressionLows = nil
            result[i].compressionLowObservedAt = nil
        }
        for timestamp in observations.sorted() {
            if let index = Self.owner(of: timestamp, sensors: result) {
                result[index].compressionLowObservedAt = min(result[index].compressionLowObservedAt ?? timestamp, timestamp)
                result[index].suspectedCompressionLows = []
            }
        }
        for timestamp in timestamps.sorted() where timestamp.isFinite {
            if let index = Self.owner(of: timestamp, sensors: result) {
                if result[index].suspectedCompressionLows == nil { result[index].suspectedCompressionLows = [] }
                result[index].suspectedCompressionLows?.append(timestamp)
            }
        }
        return result
    }
}

extension Storage {
    var suspectedCompressionLowHistory: SuspectedCompressionLowHistory {
        get {
            guard let data = UserDefaults.standard.data(forKey: "suspectedCompressionLowHistory") else { return .init() }
            return (try? JSONDecoder().decode(SuspectedCompressionLowHistory.self, from: data)) ?? .init()
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: "suspectedCompressionLowHistory")
            }
        }
    }

    @MainActor
    func recordCompressionLowObservation(timestamp: TimeInterval, suspected: Bool, recovered: Bool, now: TimeInterval) {
        var history = suspectedCompressionLowHistory
        var sensors = sensorStartNotes
        guard history.observe(timestamp: timestamp, suspected: suspected, recovered: recovered, now: now, sensors: &sensors) else { return }
        suspectedCompressionLowHistory = history
        sensorStartNotes = sensors
        NotificationCenter.default.post(name: SiteSessionService.didUpdate, object: nil)
    }
}
