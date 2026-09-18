import Foundation

extension DailyStatsViewModel {
    /// Mängd av alla kalenderdygn (startOfDay) där det finns ett pumpbyte.
    private var pumpChangeDays: Set<Date> {
        let calendar = Calendar.current
        let entries = Storage.shared.pumpChangeHistory
        guard !entries.isEmpty else { return [] }

        let days = entries.map { entry -> Date in
            let date = Date(timeIntervalSince1970: entry.date)
            return calendar.startOfDay(for: date)
        }
        return Set(days)
    }
    
    /// Mängd av alla kalenderdygn (startOfDay) där det finns ett sensorbyte.
    private var sensorChangeDays: Set<Date> {
        let calendar = Calendar.current
        let entries = Storage.shared.sensorStartNotes
        guard !entries.isEmpty else { return [] }

        let days = entries.map { entry -> Date in
            let date = Date(timeIntervalSince1970: entry.date)
            return calendar.startOfDay(for: date)
        }
        return Set(days)
    }
    
    /// Mängd av alla kalenderdygn (startOfDay) där det finns en registrerad sjukdag.
    private var sickDays: Set<Date> {
        let calendar = Calendar.current
        let entries = Storage.shared.sickDayHistory
        guard !entries.isEmpty else { return [] }

        let days = entries.map { entry -> Date in
            let date = Date(timeIntervalSince1970: entry.date)
            return calendar.startOfDay(for: date)
        }
        return Set(days)
    }

    /// Endast dagar med tillräckligt många glukosvärden (för att slippa med halva dagar).
    /// För dagens datum är vi mer tillåtande (så fort vi har något glukosvärde).
    /// Om inga dagar alls uppfyller kraven (t.ex. p.g.a. för få värden per dag),
    /// faller vi tillbaka till att visa alla dagar som har någon form av glukosdata.
    var rowsWithSufficientGlucose: [DailyStatRow] {
        let calendar = Calendar.current

        // Primär, strikt filtrering
        let strict = rows.filter { row in
            // Dagens datum: inkludera alltid om vi har något glukosvärde
            if calendar.isDateInToday(row.date) {
                return (row.glucoseCount ?? 0) > 0
            }

            // Äldre dagar: kräver minst minGlucoseReadingsPerDay värden
            if row.meanGlucoseMmol != nil, let count = row.glucoseCount {
                return count >= minGlucoseReadingsPerDay
            }
            return false
        }

        // Om vi fick minst en dag med tillräckligt många värden, använd den strikta listan.
        if !strict.isEmpty {
            return strict
        }

        // Annars: visa hellre dagar som har någon form av glukosdata
        let fallback = rows.filter { $0.meanGlucoseMmol != nil || rowHasAnyGlucoseCount($0) }
        if !fallback.isEmpty {
            return fallback
        }

        // Sista utväg
        return rows
    }

    /// Rader som ligger i scope och matchar det aktuella filtret.
    /// Antingen veckodagar (default) eller specifika pumpbytesdagar.
    var filteredRowsForDisplay: [DailyStatRow] {
        let base = rowsWithSufficientGlucose
        let calendar = Calendar.current

        // 1) Pumpbytesfilter aktivt
        if usePumpChangeDays {
            let pumpDays = pumpChangeDays
            // Om vi inte har några pumpbytesdagar alls → fall back till baslistan
            guard !pumpDays.isEmpty else { return base }

            return base.filter { row in
                let day = calendar.startOfDay(for: row.date)
                return pumpDays.contains(day)
            }
        }

        // 2) Sensorbytesfilter aktivt
        if useSensorChangeDays {
            let sensorDays = sensorChangeDays
            // Om vi inte har några sensorbytesdagar alls → fall back till baslistan
            guard !sensorDays.isEmpty else { return base }

            return base.filter { row in
                let day = calendar.startOfDay(for: row.date)
                return sensorDays.contains(day)
            }
        }
        
        // 3) Sjukdagsfilter aktivt
        if useSickDays {
            let sickDays = sickDays
            guard !sickDays.isEmpty else { return [] }

            return base.filter { row in
                let day = calendar.startOfDay(for: row.date)
                return sickDays.contains(day)
            }
        }

        // 4) Ej sjukdagsfilter aktivt
        if useNonSickDays {
            let sickDays = sickDays
            return base.filter { row in
                let day = calendar.startOfDay(for: row.date)
                return !sickDays.contains(day)
            }
        }

        // 5) Vanligt veckodagsfilter
        // Om alla veckodagar är valda → ingen extra filtrering
        guard selectedWeekdays != allWeekdaysSet else {
            return base
        }

        return base.filter { row in
            let weekday = calendar.component(.weekday, from: row.date)
            return selectedWeekdays.contains(weekday)
        }
    }
    
    /// True om något filter är aktivt (veckodagar != alla eller pumpbytesdagar).
    var isWeekdayFilterActive: Bool {
        usePumpChangeDays || useSensorChangeDays || useSickDays || useNonSickDays || selectedWeekdays != allWeekdaysSet
    }

    private func rowHasAnyGlucoseCount(_ row: DailyStatRow) -> Bool {
        (row.glucoseCount ?? 0) > 0
    }
}
