import UIKit
import Charts

extension GlucoseView {
    struct Reading {
        let date: Date
        let mmol: Double
        let trioSentAt: Date?
        let delayedReading: Bool

        init(_ entry: SGVJSON) {
            date = entry.readingDate
            mmol = Double(entry.sgv) / 18.0182
            trioSentAt = entry.trioSentAt
            delayedReading = entry.delayedReading
        }
    }

    /// Which data source to show in the table.
    enum GlucoseDataMode {
        case allValues      // Dexcom + Nightscout merged (ordinary BG cache)
        case sensorErrors   // Dexcom sensor error Notes (90d list)
    }

    /// Why a 5‑min slot is missing.
    enum MissingReason {
        case sensor       // Sensor never produced a reading (missing in both datasets)
    }

    private struct SensorErrorCacheItem: Codable {
        var id: String?
        var noteTimestamp: TimeInterval
        var durationMinutes: Int
        var notes: String?
        var enteredBy: String?
    }

    /// Row model for the table
    enum GlucoseRow {
        case glucose(Reading)
        case missing(Date, MissingReason)
        case sensorError(date: Date, durationMinutes: Int, note: Treatment)

        var date: Date {
            switch self {
            case .glucose(let e): return e.date
            case .missing(let d, _): return d
            case .sensorError(let d, _, _): return d
            }
        }

        var isMissing: Bool {
            if case .missing = self { return true }
            return false
        }
    }
}
