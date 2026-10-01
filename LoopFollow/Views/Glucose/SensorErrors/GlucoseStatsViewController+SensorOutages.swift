import UIKit
import Charts

extension GlucoseStatsViewController {
    /// Shared note-to-recovery calculation used by both sensor lists.
    func buildSensorErrorOutages(allSGV: [SGVJSON], allTreatments: [TreatmentJSON], now: Date) -> [SensorErrorOutage] {
        DexcomSensorErrorOutageCacheItem.build(readings: allSGV, treatments: allTreatments, now: now).map {
            SensorErrorOutage(noteDate: Date(timeIntervalSince1970: $0.noteTimestamp), durationMinutes: $0.durationMinutes)
        }
    }
}
