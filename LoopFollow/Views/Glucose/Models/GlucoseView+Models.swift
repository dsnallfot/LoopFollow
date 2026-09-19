import UIKit
import Charts

extension GlucoseView {
    /// Which data source to show in the table.
    enum GlucoseDataMode {
        case allValues      // Dexcom + Nightscout merged (ordinary BG cache)
        case nsOnly         // Only Trio → Nightscout uploads (NS-only cache)
        case sensorErrors   // Dexcom sensor error Notes (90d list)
    }

    /// Why a 5‑min slot is missing.
    enum MissingReason {
        case sensor       // Sensor never produced a reading (missing in both datasets)
        case trioUpload   // Trio/NS upload missing, but sensor (Dexcom) has the value
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
        case glucose(BGEntry)
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
