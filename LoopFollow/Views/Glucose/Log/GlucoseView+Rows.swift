import UIKit
import Charts

extension GlucoseView {
    // Build per-day rows, inserting missing 5‑min slots when gaps exceed ~6 minutes.
    var dayRowsIncludingMissing: [GlucoseRow] {
        if dataMode == .sensorErrors { return [] }
        let cal = Calendar.current
        let start = cal.startOfDay(for: selectedDate)
        guard let end = cal.date(byAdding: .day, value: 1, to: start) else { return [] }

        let baseEntries: [BGEntry]
        switch dataMode {
        case .allValues:
            baseEntries = allValuesDayEntries
        case .nsOnly:
            baseEntries = nsOnlyDayEntries
        case .sensorErrors:
            return []
        }

        let dayEntriesAsc = baseEntries
            .filter { $0.date >= start && $0.date < end }
            .sorted { $0.date < $1.date }

        guard !dayEntriesAsc.isEmpty else { return [] }

        var rows: [GlucoseRow] = []
        rows.reserveCapacity(dayEntriesAsc.count)

        for idx in 0..<dayEntriesAsc.count {
            let current = dayEntriesAsc[idx]
            rows.append(.glucose(current))

            // Insert missing rows between current and next
            if idx < dayEntriesAsc.count - 1 {
                let next = dayEntriesAsc[idx + 1]
                let gap = next.date.timeIntervalSince(current.date)

                // Threshold: if more than 6 min, we consider at least one missing 5‑min slot
                if gap > 360 {
                    let missingCount = Int(floor((gap - 360) / 300)) + 1
                    if missingCount > 0 {
                        for i in 1...missingCount {
                            let missingDate = current.date.addingTimeInterval(Double(i) * 300)
                            let reason = missingReason(for: missingDate)
                            rows.append(.missing(missingDate, reason))
                        }
                    }
                }
            }
        }

        // Tail-gap: insert missing slots after last actual value.
        let now = Date()
        if let lastActual = dayEntriesAsc.last {
            if cal.isDate(selectedDate, inSameDayAs: now) {
                // Today → fill to "now"
                let gapToNow = now.timeIntervalSince(lastActual.date)
                if gapToNow > 360 {
                    let missingCount = Int(floor((gapToNow - 360) / 300)) + 1
                    if missingCount > 0 {
                        for i in 1...missingCount {
                            let missingDate = lastActual.date.addingTimeInterval(Double(i) * 300)
                            if missingDate <= now {
                                let reason = missingReason(for: missingDate)
                                rows.append(.missing(missingDate, reason))
                            }
                        }
                    }
                }
            } else {
                // Historic day → fill to end-of-day (24:00)
                let gapToEnd = end.timeIntervalSince(lastActual.date)
                if gapToEnd > 360 {
                    let missingCount = Int(floor((gapToEnd - 360) / 300)) + 1
                    if missingCount > 0 {
                        for i in 1...missingCount {
                            let missingDate = lastActual.date.addingTimeInterval(Double(i) * 300)
                            if missingDate < end {
                                let reason = missingReason(for: missingDate)
                                rows.append(.missing(missingDate, reason))
                            }
                        }
                    }
                }
            }
        }

        // Table wants newest first
        return rows.sorted { $0.date > $1.date }
    }


    /// Bestäm varför ett 5‑minuters-slot saknas.
    ///
    /// - Om varken NS-only eller Alla värden har en avläsning i samma 5-minutersbucket
    ///   → behandla som sensor-miss.
    /// - Om Alla värden har en avläsning men NS-only inte har det
    ///   → behandla som Trio-upload-miss.
    private func missingReason(for date: Date) -> MissingReason {
        let bucket = Int(floor(date.timeIntervalSince1970 / 300.0))

        func hasEntry(in entries: [BGEntry]) -> Bool {
            entries.contains { entry in
                let b = Int(floor(entry.date.timeIntervalSince1970 / 300.0))
                return b == bucket
            }
        }

        let hasAllValues = hasEntry(in: allValuesDayEntries)
        let hasNSOnly    = hasEntry(in: nsOnlyDayEntries)

        if !hasAllValues && !hasNSOnly {
            return .sensor
        }
        if hasAllValues && !hasNSOnly {
            return .trioUpload
        }
        // Fallback
        return .sensor
    }
}
