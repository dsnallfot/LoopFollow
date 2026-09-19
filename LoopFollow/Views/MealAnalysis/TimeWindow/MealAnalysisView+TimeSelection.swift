import UIKit

extension MealAnalysisView {
    // MARK: - Actions

    // MARK: - Time calculations

    @objc func startTimeChanged(_ sender: UIDatePicker) {
        // Drop "1h…24h" selection when manually adjusting dates => markera "☆"
        if (0...5).contains(durationControl.selectedSegmentIndex) {
            durationControl.selectedSegmentIndex = freeSegmentIndex
        }
        // Grab the (optional) title now that we might have changed it
        let title = durationControl.selectedSegmentIndex >= 0 ? durationControl.titleForSegment(at: durationControl.selectedSegmentIndex) : nil
        let calendar = Calendar.current

        if title == "Ⓢ" {
            // Schoolday: always 08:00 → (now if before 16:00 today, else 16:00)
            let comps = calendar.dateComponents([.year, .month, .day], from: sender.date)
            let newStart = calendar.date(from: DateComponents(
                year: comps.year, month: comps.month, day: comps.day,
                hour: 8, minute: 0
            ))!
            let schoolEnd = calendar.date(from: DateComponents(
                year: comps.year, month: comps.month, day: comps.day,
                hour: 16, minute: 00
            ))!
            let newEnd: Date
            if calendar.isDateInToday(sender.date), Date() < schoolEnd {
                newEnd = Date()
            } else {
                newEnd = schoolEnd
            }

            startTime = newStart
            endTime   = newEnd
            startPicker.date = newStart
            endPicker.date   = newEnd

        } else if title == "Dag" {
            // Full calendar day: midnight → (now if today, else next midnight)
            let comps = calendar.dateComponents([.year, .month, .day], from: sender.date)
            let newStart = calendar.date(from: DateComponents(
                year: comps.year, month: comps.month, day: comps.day,
                hour: 0, minute: 0
            ))!
            let newEnd: Date
            if calendar.isDateInToday(sender.date) {
                newEnd = Date()
            } else {
                newEnd = calendar.date(byAdding: .day, value: 1, to: newStart)!
            }

            startTime = newStart
            endTime   = newEnd
            startPicker.date = newStart
            endPicker.date   = newEnd

        } else if title == "☆" {
            // Fri-läge: helt fritt fönster, bara uppdatera startTime
            startTime = sender.date
        } else {
            // Other modes (timestamp modal or fixed durations)
            startTime = sender.date
            if modalWithTimestamp {
                recalcEndTimeBasedOnDuration()
            }
        }

        // Update UI for all cases
        updateTotals()
        updateBGLabels()
    }

    @objc func durationChanged(_ sender: UISegmentedControl) {
        let calendar = Calendar.current
        let newIdx = sender.selectedSegmentIndex
        guard newIdx != UISegmentedControl.noSegment,
              newIdx < sender.numberOfSegments,
              let newTitle = sender.titleForSegment(at: newIdx) else {
            return
        }

        // 🔐 Extra safety: om tidsfönstret är trasigt (eller inte satt än) – använd bara standardlogik
        if endTime <= startTime {
            recalcEndTimeBasedOnDuration()
            lastDurationTitle = newTitle
            updateTotals()
            updateBGLabels()
            return
        }

        let previousTitle = lastDurationTitle

        // Special handling: när vi står i "Dag" och byter till en tim-preset (1h–24h)
        // – men BARA i så fall.
        if let previousTitle,
           previousTitle == "Dag",
           ["1h", "2h", "3h", "6h", "12h", "24h"].contains(newTitle) {

            let dayStart = calendar.startOfDay(for: startTime)
            let isToday = calendar.isDateInToday(dayStart)
            let hours = Int(newTitle.replacingOccurrences(of: "h", with: "")) ?? 1

            if isToday {
                // Idag: clamp end till nu, rullande X timmar bakåt
                let now = Date()
                endTime = now
                var newStart = calendar.date(byAdding: .hour, value: -hours, to: now) ?? now
                if let minDate = startPicker.minimumDate, newStart < minDate {
                    newStart = minDate
                }
                startTime = newStart
            } else {
                // Äldre dag: fönster från 00:00 -> +X timmar (max till nästa midnatt)
                let dayStart = calendar.startOfDay(for: startTime)
                startTime = dayStart
                var newEnd = calendar.date(byAdding: .hour, value: hours, to: dayStart) ?? dayStart
                let nextMidnight = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? newEnd
                if newEnd > nextMidnight {
                    newEnd = nextMidnight
                }
                endTime = newEnd
            }

            // Synca pickers
            startPicker.date = startTime
            endPicker.date = endTime

            lastDurationTitle = newTitle
            updateTotals()
            updateBGLabels()
            return
        }

        // Defaultbeteende för alla andra byten
        recalcEndTimeBasedOnDuration()
        lastDurationTitle = newTitle
        updateTotals()
        updateBGLabels()
    }

    @objc func endTimeChanged(_ sender: UIDatePicker) {
        // Drop "1h…24h" selection when manually adjusting dates => markera "☆"
        if (0...5).contains(durationControl.selectedSegmentIndex) {
            durationControl.selectedSegmentIndex = freeSegmentIndex
        }
        // Grab the (optional) title now that we might have changed it
        let title = durationControl.selectedSegmentIndex >= 0 ? durationControl.titleForSegment(at: durationControl.selectedSegmentIndex) : nil
        let calendar = Calendar.current

        if title == "Ⓢ" {
            // Schoolday: always 08:00 → (now if before 16:00 today, else 16:00)
            let comps = calendar.dateComponents([.year, .month, .day], from: sender.date)
            let newStart = calendar.date(from: DateComponents(
                year: comps.year, month: comps.month, day: comps.day,
                hour: 8, minute: 0
            ))!
            let schoolEnd = calendar.date(from: DateComponents(
                year: comps.year, month: comps.month, day: comps.day,
                hour: 16, minute: 00
            ))!
            let newEnd: Date
            if calendar.isDateInToday(sender.date), Date() < schoolEnd {
                newEnd = Date()
            } else {
                newEnd = schoolEnd
            }

            startTime = newStart
            endTime   = newEnd
            startPicker.date = newStart
            endPicker.date   = newEnd

        } else if title == "Dag" {
            // Full calendar day: midnight → (now if today, else next midnight)
            let comps = calendar.dateComponents([.year, .month, .day], from: sender.date)
            let newStart = calendar.date(from: DateComponents(
                year: comps.year, month: comps.month, day: comps.day,
                hour: 0, minute: 0
            ))!
            let newEnd: Date
            if calendar.isDateInToday(sender.date) {
                newEnd = Date()
            } else {
                newEnd = calendar.date(byAdding: .day, value: 1, to: newStart)!
            }

            startTime = newStart
            endTime   = newEnd
            startPicker.date = newStart
            endPicker.date   = newEnd

        } else if title == "☆" {
            // Fri-läge: fritt slutdatum, men clamp:a fortfarande till nu om man väljer framtid
            var selected = sender.date
            let now = Date()
            if selected > now {
                selected = now
                sender.date = now
            }
            endTime = selected
        } else {
            // Other modes
            var selected = sender.date
            let now = Date()
            if selected > now {
                selected = now
                sender.date = now
            }
            endTime = selected
            if modalWithTimestamp {
                recalcEndTimeBasedOnDuration()
            }
        }

        updateTotals()
        updateBGLabels()

        updateTotals()
        updateBGLabels()
    }
    
    func recalcEndTimeBasedOnDuration() {
        let idx = durationControl.selectedSegmentIndex
        guard idx != UISegmentedControl.noSegment,
              idx < durationControl.numberOfSegments,
              let title = durationControl.titleForSegment(at: idx) else { return }
        let calendar = Calendar.current

        if title == "Dag" {
            // Full calendar day: midnight → (now if today, else next midnight)
            let dayStart = calendar.startOfDay(for: startTime)
            startTime = dayStart
            let newEnd: Date
            if calendar.isDateInToday(dayStart) {
                newEnd = Date()
            } else {
                newEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!
            }
            endTime = newEnd
            startPicker.date = startTime
            endPicker.date = endTime

        } else if title == "Ⓢ" {
            // Schoolday: always 08:00 → (now if before 16:00; else 16:00)
            // Use the same calendar-day as startTime (preserves date if you entered via modal)
            let comps = calendar.dateComponents([.year, .month, .day], from: startTime)
            let newStart = calendar.date(from: DateComponents(
                year: comps.year, month: comps.month, day: comps.day,
                hour: 8, minute: 0
            ))!
            let schoolEnd = calendar.date(from: DateComponents(
                year: comps.year, month: comps.month, day: comps.day,
                hour: 16, minute: 00
            ))!
            let newEnd: Date
            if calendar.isDateInToday(newStart), Date() < schoolEnd {
                // if it’s today *and* before 16:00, end = now
                newEnd = Date()
            } else {
                // otherwise end = 16:00 of that day
                newEnd = schoolEnd
            }
            startTime = newStart
            endTime   = newEnd
            startPicker.date = newStart
            endPicker.date   = newEnd
            
        } else if title == "☆" {
            // Fri-läge: gör ingenting här, start/end styrs helt av pickers
            return
        } else {
            // Hacker for “1h”, “2h”, etc., or modal-with-timestamp
            let hoursString = title.replacingOccurrences(of: "h", with: "")
            let hours = Int(hoursString) ?? 1

            if modalWithTimestamp {
                // From startTime + hours → endTime
                endTime = calendar.date(byAdding: .hour, value: hours, to: startTime)!
                if endTime > Date() {
                    endTime = Date()
                }
                endPicker.date = endTime
            } else {
                // From endTime − hours → startTime
                startTime = calendar.date(byAdding: .hour, value: -hours, to: endTime)!
                startPicker.date = startTime
            }
        }
        updateTotals()
        updateBGLabels()
    }

    /// Integrate scheduled profile basal (units) between two dates
}
